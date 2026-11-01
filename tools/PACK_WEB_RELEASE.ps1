$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $project 'dist/web-release'
New-Item -ItemType Directory -Path $stage,(Join-Path $stage 'build-web'),(Join-Path $stage 'tools'),(Join-Path $stage 'licenses') -Force | Out-Null
foreach ($name in @('RUN_WEB.cmd','RUN_WEB.ps1')) {
    Copy-Item -LiteralPath (Join-Path $project $name) -Destination (Join-Path $stage $name) -Force
}
Copy-Item -LiteralPath (Join-Path $project 'tools/serve-web.mjs') -Destination (Join-Path $stage 'tools/serve-web.mjs') -Force
foreach ($name in @('index.html','index.js','index.wasm','index.pck','index.png','index.icon.png','index.apple-touch-icon.png','index.audio.worklet.js','index.audio.position.worklet.js','presentation-state.js')) {
    Copy-Item -LiteralPath (Join-Path $project ('build-web/'+$name)) -Destination (Join-Path $stage ('build-web/'+$name)) -Force
}
foreach ($name in @('GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt')) {
    Copy-Item -LiteralPath (Join-Path $project ('.tools/'+$name)) -Destination (Join-Path $stage ('licenses/'+$name)) -Force
}
Copy-Item -LiteralPath (Join-Path $project 'assets/audio/CREDITS.md') -Destination (Join-Path $stage 'licenses/AUDIO-CREDITS.md') -Force
Copy-Item -LiteralPath (Join-Path $project 'WEB_RELEASE.md') -Destination (Join-Path $stage 'README.md') -Force
$archive = Join-Path $project 'dist/VELUM-web.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $archive -CompressionLevel Optimal -Force
Get-FileHash -LiteralPath $archive -Algorithm SHA256
