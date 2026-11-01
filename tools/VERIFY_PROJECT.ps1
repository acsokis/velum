$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$engine = Join-Path $projectRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$cases = @(
    @{Name='smoke';Arguments=@('--','--smoke')},
    @{Name='normals';Arguments=@('--script','res://tools/audit_normals.gd')},
    @{Name='systems';Arguments=@('--script','res://tools/verify_systems.gd')},
    @{Name='ecology';Arguments=@('--script','res://tools/verify_ecosystem.gd')},
    @{Name='organisms';Arguments=@('--script','res://tools/verify_organisms.gd')},
    @{Name='ramps';Arguments=@('--','--terrain-test')},
    @{Name='labyrinth';Arguments=@('--script','res://tools/verify_labyrinth.gd','--','--maze-test')},
    @{Name='spectral';Arguments=@('--script','res://tools/verify_spectral.gd')},
    @{Name='seed-detail';Arguments=@('--script','res://tools/verify_seed_detail.gd','--','--maze-test')}
)
foreach ($case in $cases) {
    $log = Join-Path $projectRoot ('runtime/verify-'+$case.Name+'.log')
    & $engine --headless --path $projectRoot --log-file $log @($case.Arguments)
    if ($LASTEXITCODE -ne 0) { throw ('Failed runtime case: '+$case.Name) }
    $gameErrors = Get-Content -LiteralPath $log | Where-Object {
        ($_ -match '^(SCRIPT ERROR:|ERROR:)') -and ($_ -ne 'ERROR: Failed to read the root certificate store.')
    }
    if ($gameErrors) { throw ('Runtime errors in '+$case.Name+': '+($gameErrors -join ' / ')) }
}
Push-Location -LiteralPath $projectRoot
try {
    & node --test tests/link.test.mjs tests/presentation.test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'LINK/presentation tests failed' }
} finally { Pop-Location }
Write-Output 'VELUM_PROJECT_CHECKS_PASS: nine real-engine runtime cases + 21 Node assertions/subtests.'
