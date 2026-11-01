$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$engine = Join-Path $PSScriptRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $engine --headless --path $PSScriptRoot --script res://tools/pack.gd
if ($LASTEXITCODE -ne 0) { throw 'Pack build failed' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '.tools\godot\Godot_v4.7.2-stable_win64.exe') -Destination (Join-Path $PSScriptRoot 'build\VELUM.exe') -Force
foreach ($notice in @('GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt')) {
    $sourceNotice = Join-Path $PSScriptRoot ('.tools\' + $notice)
    if (Test-Path -LiteralPath $sourceNotice) { Copy-Item -LiteralPath $sourceNotice -Destination (Join-Path $PSScriptRoot ('build\' + $notice)) -Force }
}
Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'build\VELUM.exe'),(Join-Path $PSScriptRoot 'build\VELUM.pck') -Algorithm SHA256 | Format-Table Path,Hash
Write-Output 'Portable developer build ready. Uses the verified full Godot binary, not stripped export templates.'
