$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$project = Split-Path -Parent $PSScriptRoot
$source = Join-Path $project '.tools\rtx-source\godot-135dff3887a3d2ccf45cafbd9bdffa7b718e1e76'
$deps = Join-Path $project '.tools\rtx-deps'
$env:PYTHONPATH = Join-Path $project '.tools\pydeps'
$taskTemp = Join-Path $project '.tools\rtx-temp'
New-Item -ItemType Directory -Path $deps,$taskTemp -Force | Out-Null
$env:TEMP = $taskTemp
$env:TMP = $taskTemp
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Fetch-Archive([string]$Url,[string]$Name,[string]$Folder) {
    $archive = Join-Path $deps $Name
    $destination = Join-Path $deps $Folder
    if (-not (Test-Path -LiteralPath $archive)) { Invoke-WebRequest -Uri $Url -OutFile $archive }
    if (-not (Test-Path -LiteralPath (Join-Path $destination '.complete'))) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        $resolved = [IO.Path]::GetFullPath($destination).TrimEnd('\') + '\'
        $zip = [IO.Compression.ZipFile]::OpenRead($archive)
        try {
            foreach ($entry in $zip.Entries) {
                $target = [IO.Path]::GetFullPath((Join-Path $destination $entry.FullName))
                if (-not $target.StartsWith($resolved,[StringComparison]::OrdinalIgnoreCase)) { throw 'Archive path escaped target directory' }
                if ($entry.Name -eq '') { New-Item -ItemType Directory -Path $target -Force | Out-Null; continue }
                New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force | Out-Null
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$true)
            }
        } finally { $zip.Dispose() }
        (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash | Set-Content -LiteralPath (Join-Path $destination '.complete')
    }
}
Fetch-Archive 'https://github.com/godotengine/godot-nir-static/releases/download/25.3.1-3/godot-nir-static-x86_64-msvc-release.zip' 'mesa.zip' 'mesa'
Fetch-Archive 'https://www.nuget.org/api/v2/package/Microsoft.Direct3D.D3D12/1.618.5' 'agility.zip' 'agility'
Fetch-Archive 'https://github.com/NVIDIA-RTX/Streamline/releases/download/v2.10.0/streamline-sdk-v2.10.0.zip' 'streamline.zip' 'streamline'
if (-not (Test-Path -LiteralPath (Join-Path $project '.tools\pydeps\mako'))) {
    python -m pip install --disable-pip-version-check --cache-dir (Join-Path $project '.tools\pip-cache') --target (Join-Path $project '.tools\pydeps') 'Mako==1.3.10'
    if ($LASTEXITCODE -ne 0) { throw 'Mako setup failed' }
}
$vcvars = 'C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat'
$environment = & cmd.exe /d /c ('call "' + $vcvars + '" >nul && set')
if ($LASTEXITCODE -ne 0) { throw 'Existing Visual Studio C++ environment failed' }
foreach ($line in $environment) {
    $split = $line.IndexOf('=')
    if ($split -gt 0) { [Environment]::SetEnvironmentVariable($line.Substring(0,$split),$line.Substring($split+1),'Process') }
}
$env:PYTHONPATH = Join-Path $project '.tools\pydeps'
Set-Location -LiteralPath $source
$buildLog = Join-Path $project 'runtime\rtx-compile.log'
$arguments = @('platform=windows','target=template_release','arch=x86_64','d3d12=yes','use_pix=no','accesskit=no','use_streamline=yes','debug_symbols=no','lto=none','optimize=speed','-j8',('mesa_libs='+(Join-Path $deps 'mesa')),('agility_sdk_path='+(Join-Path $deps 'agility')))
$ErrorActionPreference = 'Continue'
& python -m SCons @arguments *> $buildLog
$buildExit = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($buildExit -ne 0) { Get-Content -LiteralPath $buildLog -Tail 45; throw 'NVIDIA Godot build failed' }
$output = Join-Path $project 'build-rtx'
New-Item -ItemType Directory -Path $output -Force | Out-Null
$binary = Join-Path $source 'bin\godot.windows.template_release.x86_64.exe'
if (-not (Test-Path -LiteralPath $binary)) { throw 'Expected NVIDIA Godot binary missing' }
Copy-Item -LiteralPath $binary -Destination (Join-Path $output 'VELUM.exe') -Force
Copy-Item -LiteralPath (Join-Path $project 'build\VELUM.pck') -Destination (Join-Path $output 'VELUM.pck') -Force
$interposer = @(Get-ChildItem -LiteralPath (Join-Path $deps 'streamline') -Filter 'sl.interposer.dll' -Recurse | Where-Object FullName -NotMatch 'development|debug')
if ($interposer.Count -ne 1) { throw 'Expected one production Streamline interposer' }
$runtime = $interposer[0].DirectoryName
foreach ($name in @('sl.interposer.dll','sl.common.dll','sl.dlss.dll','sl.dlss_g.dll','sl.dlss_d.dll','sl.reflex.dll','sl.pcl.dll','sl.nis.dll','nvngx_dlss.dll','nvngx_dlssg.dll','nvngx_dlssd.dll')) {
    $file = Join-Path $runtime $name
    if (-not (Test-Path -LiteralPath $file)) { continue }
    $signature = Get-AuthenticodeSignature -LiteralPath $file
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'NVIDIA') { throw ('Unverified NVIDIA runtime: '+$name) }
    Copy-Item -LiteralPath $file -Destination (Join-Path $output $name) -Force
}
$core = Join-Path $deps 'agility\build\native\bin\x64\D3D12Core.dll'
$coreSignature = Get-AuthenticodeSignature -LiteralPath $core
if ($coreSignature.Status -ne 'Valid' -or $coreSignature.SignerCertificate.Subject -notmatch 'Microsoft') { throw 'Unverified Microsoft DX12 runtime' }
Copy-Item -LiteralPath $core -Destination (Join-Path $output 'D3D12Core.dll') -Force
Get-ChildItem -LiteralPath $output -Filter '*.dll' | Get-FileHash -Algorithm SHA256 | Select-Object @{n='Name';e={[IO.Path]::GetFileName($_.Path)}},Hash | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'runtime-integrity.json')
Copy-Item -LiteralPath (Join-Path $source 'LICENSE.txt') -Destination (Join-Path $output 'GODOT-LICENSE.txt') -Force
Copy-Item -LiteralPath (Join-Path $source 'COPYRIGHT.txt') -Destination (Join-Path $output 'GODOT-COPYRIGHT.txt') -Force
Copy-Item -LiteralPath (Join-Path $runtime 'nvngx_dlss.license.txt'),(Join-Path $runtime 'reflex.license.txt'),(Join-Path $runtime 'nis.license.txt'),(Join-Path $deps 'streamline\3rd-party-licenses.md') -Destination $output -Force
Get-ChildItem -LiteralPath (Join-Path $deps 'streamline') -File -Recurse | Where-Object Name -Match '^(LICENSE|LICENSE.txt|LICENSE.md|EULA.txt)$' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $output ('NVIDIA-'+$_.Name)) -Force }
Write-Output 'VELUM_RTX_ENGINE_BUILD_PASS official NVIDIA source, signed production runtime, all output on D:'
