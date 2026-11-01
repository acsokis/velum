param([switch]$MazeOnly)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$target = Join-Path $project 'build-rtx'
$results = @{}
$frameGenerationVerified = $true
$cases = if ($MazeOnly) { @('maze') } else { @('full','voxel') }
foreach ($case in $cases) {
    $logPath = Join-Path $project ('runtime\rtx-vulkan-' + $case + '.log')
    $lines = Get-Content -LiteralPath $logPath
	if ($MazeOnly -and -not ($lines -match 'VELUM_VOXELGI_BAKE_COMPLETE cells_bytes=[1-9]')) { throw 'Current maze VoxelGI bake was not confirmed' }
    if (-not ($lines -match 'VELUM_DLSS_RUNTIME_PASS SR=true FG=(true|false)')) { throw ('RTX test did not pass: '+$case) }
    $line = @($lines | Where-Object { $_ -match 'VELUM_DLSS_DIAGNOSTICS' })[-1]
    $data = ($line.Substring($line.IndexOf('{')) | ConvertFrom-Json)
    if ($data.sr_frames -le 0) { throw 'Runtime counters did not confirm DLSS SR' }
    $caseHasFG = ($lines -match 'VELUM_DLSS_RUNTIME_PASS SR=true FG=true') -and $data.fg_extra_frames -gt 0 -and $data.fg_status -eq 0
    if (($lines -match 'VELUM_DLSS_RUNTIME_PASS SR=true FG=true') -and -not $caseHasFG) { throw 'FG pass claim contradicts native counters' }
    if (-not $caseHasFG) { $frameGenerationVerified = $false }
    $results[$case] = $data
}
Get-ChildItem -LiteralPath $target -Filter '*.dll' | Get-FileHash -Algorithm SHA256 | Select-Object @{n='Name';e={[IO.Path]::GetFileName($_.Path)}},Hash | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $target 'runtime-integrity.json')
$record = [ordered]@{
    sourceCommit = '135dff3887a3d2ccf45cafbd9bdffa7b718e1e76'
    engine = '4.8.dev NVIDIA fork + VELUM runtime counters / pinned runtime'
    renderer = 'vulkan'
    adapter = 'NVIDIA GeForce RTX 4080'
    frame_generation_verified = $frameGenerationVerified
    executableSha256 = (Get-FileHash -LiteralPath (Join-Path $target 'VELUM.exe')).Hash
    packageSha256 = (Get-FileHash -LiteralPath (Join-Path $target 'VELUM.pck')).Hash
    results = $results
    validationScope = if ($MazeOnly) { 'Current layered labyrinth / VoxelGI 512 / native fog / DLSS SR; FG unavailable' } else { 'Survey sector / SDFGI + VoxelGI' }
}
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $target 'validated.json')
Write-Output ('VELUM_RTX_VALIDATED Vulkan / '+$record.validationScope+' / FG verified='+$frameGenerationVerified)
