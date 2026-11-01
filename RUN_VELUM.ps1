param([switch]$Build, [switch]$Smoke, [switch]$DX12, [switch]$RTX, [switch]$Source)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if (-not $Source) { $Build = $true; if (-not $DX12) { $RTX = $true } }
$engine = Join-Path $PSScriptRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
if ($Source -and -not (Test-Path -LiteralPath $engine)) { throw 'Portable Godot missing from project .tools folder.' }
New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'runtime') -Force | Out-Null
$env:VELUM_DATA_DIR = Join-Path $PSScriptRoot 'runtime'
. (Join-Path $PSScriptRoot 'tools\Test-RtxPackage.ps1')
$rtxHardware = $false
try { $rtxHardware = @((Get-CimInstance Win32_VideoController -ErrorAction Stop) | Where-Object { $_.Name -match 'NVIDIA.*RTX' }).Count -gt 0 } catch { }
$useRtx = $Build -and (-not $DX12) -and $rtxHardware -and (Test-VelumRtxPackage $PSScriptRoot)
if ($RTX -and -not $useRtx) { Write-Output 'RTX hardware/package unavailable: using the standard Direct3D 12 build.' }
$server = $null
$env:VELUM_LINK_DISABLED = '1'
$linkSocket = [Net.Sockets.TcpClient]::new()
try {
    $connected = $linkSocket.ConnectAsync('127.0.0.1',8787)
    $portBusy = $connected.Wait(500) -and $linkSocket.Connected
} catch { $portBusy = $false } finally { $linkSocket.Dispose() }
if ($portBusy) {
    Write-Warning 'LINK port 8787 is already in use. Starting the game offline; the existing process is left running.'
} elseif ((Test-Path -LiteralPath (Join-Path $PSScriptRoot 'server.mjs')) -and (Get-Command node.exe -ErrorAction SilentlyContinue)) {
    try {
        $server = Start-Process -FilePath (Get-Command node.exe).Source -ArgumentList 'server.mjs' -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput 'runtime\link.log' -RedirectStandardError 'runtime\link-error.log'
        Start-Sleep -Milliseconds 700
        if (-not $server.HasExited) { $env:VELUM_LINK_DISABLED = '0' }
        else { Write-Warning 'LINK could not start. The game remains playable offline.' }
    } catch { Write-Warning 'LINK could not start. The game remains playable offline.' }
} else { Write-Warning 'Node.js is unavailable. Starting without the optional LINK companion.' }
try {
    if ($Build) {
        $gameDirectory = Join-Path $PSScriptRoot 'build-rtx'
        if ($useRtx) {
            $gameArgs = @('--rendering-driver','vulkan','--log-file',('"'+(Join-Path $PSScriptRoot 'runtime\rtx-game.log')+'"'))
            $rtxRecord = Get-Content -LiteralPath (Join-Path $gameDirectory 'validated.json') -Raw | ConvertFrom-Json
            Write-Output ('VELUM profile: NVIDIA / Vulkan / native DLSS / Frame Generation verified='+$rtxRecord.frame_generation_verified)
        } else {
            $gameDirectory = Join-Path $PSScriptRoot 'build'
            $gameArgs = @('--main-pack', ('"' + (Join-Path $PSScriptRoot 'build\VELUM.pck') + '"'), '--rendering-driver', 'd3d12', '--log-file', ('"' + (Join-Path $PSScriptRoot 'runtime\build-game.log') + '"'))
            Write-Output 'VELUM profile: standard Godot / Direct3D 12'
        }
        if ($Smoke) { $gameArgs += @('--headless', '--', '--smoke') }
        $game = Start-Process -FilePath (Join-Path $gameDirectory 'VELUM.exe') -ArgumentList $gameArgs -WorkingDirectory $gameDirectory -Wait -PassThru
        if ($game.ExitCode -ne 0) { throw ('VELUM exited with ' + $game.ExitCode) }
    } else {
        $extraArgs = @()
        if ($Smoke) { $extraArgs = @('--headless', '--', '--smoke') }
        & $engine --path $PSScriptRoot --rendering-driver d3d12 --log-file (Join-Path $PSScriptRoot 'runtime\game.log') @extraArgs
        if ($LASTEXITCODE -ne 0) { throw ('VELUM exited with ' + $LASTEXITCODE) }
    }
} finally {
    if ($null -ne $server -and -not $server.HasExited) { Stop-Process -Id $server.Id }
}
