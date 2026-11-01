param([switch]$NoBrowser, [ValidateRange(1024,65535)][int]$Port = 8789)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$url = 'http://127.0.0.1:'+ $Port +'/'
foreach ($file in @('index.html','index.js','index.wasm','index.pck')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot ('build-web/'+$file)))) {
        throw 'The web build is missing. Extract the VELUM web release beside this launcher, or run BUILD_WEB.ps1 from a configured developer checkout.'
    }
}
function Test-VelumWeb {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 2
        return $response.StatusCode -eq 200 -and $response.Content -match '<title>VELUM</title>'
    } catch { return $false }
}
if (-not (Test-VelumWeb)) {
    $node = Get-Command node.exe -ErrorAction SilentlyContinue
    if (-not $node) { throw 'Node.js 22 or newer is required for the local web launcher.' }
    New-Item -ItemType Directory -Path 'runtime' -Force | Out-Null
    $env:VELUM_WEB_PORT = [string]$Port
    $webServer = Start-Process -FilePath $node.Source -ArgumentList 'tools/serve-web.mjs' -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput 'runtime/web-launch.log' -RedirectStandardError 'runtime/web-launch-error.log'
    $ready = $false
    for ($attempt = 0; $attempt -lt 15; $attempt++) {
        if ($webServer.HasExited) { throw ('Web server failed to start. Port '+$Port+' may belong to another application; see runtime/web-launch-error.log.') }
        if (Test-VelumWeb) { $ready = $true;break }
        Start-Sleep -Milliseconds 200
    }
    if (-not $ready) { throw 'Web server did not become ready; see runtime/web-launch-error.log.' }
    Write-Output ('Server PID: '+$webServer.Id)
}
Write-Output ('VELUM web game ready: '+$url)
if (-not $NoBrowser) { Start-Process $url }
