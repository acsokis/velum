$ErrorActionPreference = 'Stop'
$env:GIT_TERMINAL_PROMPT = '0'
$env:GCM_INTERACTIVE = 'never'
$credentialText = (@('protocol=https','host=github.com','') -join "`n") | git credential fill 2>$null
$credentials = @{}
foreach ($line in $credentialText) {
    $parts = $line -split '=',2
    if ($parts.Count -eq 2) { $credentials[$parts[0]] = $parts[1] }
}
if (-not $credentials.password) { throw 'GitHub credential unavailable' }
$headers = @{Authorization=('Bearer '+$credentials.password);'User-Agent'='VELUM-release';Accept='application/vnd.github+json'}
$api = 'https://api.github.com/repos/acsokis/velum'
$pages = $null
try { $pages = Invoke-RestMethod -Uri "$api/pages" -Headers $headers } catch {
    if ([int]$_.Exception.Response.StatusCode -ne 404) { throw }
}
if ($null -eq $pages) {
    $pages = Invoke-RestMethod -Method Post -Uri "$api/pages" -Headers $headers -ContentType 'application/json' -Body '{"build_type":"workflow"}'
} elseif ($pages.build_type -ne 'workflow') {
    $pages = Invoke-RestMethod -Method Put -Uri "$api/pages" -Headers $headers -ContentType 'application/json' -Body '{"build_type":"workflow"}'
}
Write-Output ('Pages: '+$pages.html_url)
$release = Invoke-RestMethod -Uri "$api/releases/tags/v0.1.0-preview" -Headers $headers
$archive = Join-Path (Split-Path $PSScriptRoot -Parent) 'dist/VELUM-Windows.zip'
$existing = @($release.assets | Where-Object name -eq 'VELUM-Windows.zip')
if ($existing.Count -gt 0) { throw 'Desktop asset already exists; refusing replacement' }
$upload = ($release.upload_url -replace '\{.*\}$','')+'?name=VELUM-Windows.zip'
$asset = Invoke-RestMethod -Method Post -Uri $upload -Headers $headers -ContentType 'application/zip' -InFile $archive
Write-Output ('Desktop: '+$asset.browser_download_url)
Write-Output ('Size: '+$asset.size+'; digest: '+$asset.digest)
$headers.Clear()
$credentials.Clear()
$credentialText = $null
