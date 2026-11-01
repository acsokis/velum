$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$engine = Join-Path $PSScriptRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath '.tools\web\web_nothreads_release.zip')) { throw 'Run tools/SETUP_WEB_TEMPLATES.ps1 first (official downloads, D: only).' }
New-Item -ItemType Directory -Path 'build-web' -Force | Out-Null
New-Item -ItemType Directory -Path 'build-web/fast' -Force | Out-Null
foreach ($webName in @('web_release.zip','web_debug.zip')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('.tools/web/'+$webName)) -Destination (Join-Path $PSScriptRoot ('.tools/godot/editor_data/export_templates/4.7.2.stable/'+$webName)) -Force
}
& $engine --headless --path $PSScriptRoot --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Web resource import failed' }
& $engine --headless --path $PSScriptRoot --export-release Web 'build-web/index.html'
if ($LASTEXITCODE -ne 0) { throw 'Web export failed' }
& $engine --headless --path $PSScriptRoot --export-release WebFast 'build-web/fast/index.html'
if ($LASTEXITCODE -ne 0) { throw 'Threaded web export failed' }
Copy-Item -LiteralPath 'web/presentation-state.js' -Destination 'build-web/presentation-state.js' -Force
Copy-Item -LiteralPath 'web/presentation-state.js' -Destination 'build-web/fast/presentation-state.js' -Force
Get-ChildItem -LiteralPath 'build-web' -File | Select-Object Name,Length
