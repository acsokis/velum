$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $project 'dist/desktop-release'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
foreach ($name in @('VELUM.exe','VELUM.pck','GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt')) {
    Copy-Item -LiteralPath (Join-Path $project ('build/'+$name)) -Destination (Join-Path $stage $name) -Force
}
Copy-Item -LiteralPath (Join-Path $project 'assets/audio/CREDITS.md') -Destination (Join-Path $stage 'AUDIO-CREDITS.md') -Force
Copy-Item -LiteralPath (Join-Path $project 'tools/desktop-release.cmd') -Destination (Join-Path $stage 'RUN_VELUM.cmd') -Force
Copy-Item -LiteralPath (Join-Path $project 'DESKTOP_RELEASE.md') -Destination (Join-Path $stage 'README.md') -Force
$archive = Join-Path $project 'dist/VELUM-Windows.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $archive -CompressionLevel Optimal -Force
Get-FileHash -LiteralPath $archive -Algorithm SHA256
