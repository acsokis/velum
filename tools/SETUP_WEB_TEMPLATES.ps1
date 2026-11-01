$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $projectRoot '.tools\web'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$archive = Join-Path $destination 'templates.tpz'
$baseUrl = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/'
$sumsPath = Join-Path $destination 'SHA512-SUMS.txt'
Invoke-WebRequest -Uri ($baseUrl + 'SHA512-SUMS.txt') -OutFile $sumsPath
$archiveName = 'Godot_v4.7.2-stable_export_templates.tpz'
$checksumLine = Get-Content -LiteralPath $sumsPath | Where-Object { $_ -match [regex]::Escape($archiveName) + '$' }
if (-not $checksumLine) { throw 'Official archive checksum missing' }
$expected = ($checksumLine -split '\s+')[0]
if (-not (Test-Path -LiteralPath $archive)) {
    & curl.exe --fail --location --retry 2 --output $archive ($baseUrl + $archiveName)
    if ($LASTEXITCODE -ne 0) { throw 'Template download failed' }
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA512).Hash -ne $expected) { throw 'Template checksum mismatch' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    foreach ($templateName in @('web_nothreads_release.zip', 'web_nothreads_debug.zip','web_release.zip','web_debug.zip')) {
        $entry = $zip.GetEntry('templates/' + $templateName)
        if (-not $entry) { throw "Missing official template $templateName" }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $destination $templateName), $true)
        $portableTemplates = Join-Path $projectRoot '.tools\godot\editor_data\export_templates\4.7.2.stable'
        New-Item -ItemType Directory -Path $portableTemplates -Force | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $portableTemplates $templateName), $true)
    }
} finally { $zip.Dispose() }
Write-Output 'WEB_TEMPLATES_SHA512_VERIFIED: official 4.7.2, extracted only web templates on D:'
