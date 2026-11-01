$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$openssl = 'C:\Program Files\Git\usr\bin\openssl.exe'
if (-not (Test-Path -LiteralPath $openssl)) { throw 'Existing Git OpenSSL not found. No software was installed.' }
$data = Join-Path $PSScriptRoot 'runtime'
New-Item -ItemType Directory -Path $data -Force | Out-Null
$cert = Join-Path $data 'tls-cert.pem'
$key = Join-Path $data 'tls-key.pem'
if ((Test-Path -LiteralPath $cert) -or (Test-Path -LiteralPath $key)) { throw 'Certificate or key already exists; preserving it.' }
$addresses = @(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -match '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' } | Select-Object -ExpandProperty IPAddress -Unique)
$san = 'DNS:localhost,IP:127.0.0.1'
foreach ($address in $addresses) { $san += ',IP:' + $address }
& $openssl req -x509 -newkey rsa:2048 -sha256 -nodes -keyout $key -out $cert -days 7 -subj '/CN=VELUM LINK local prototype' -addext ('subjectAltName=' + $san)
if ($LASTEXITCODE -ne 0) { throw 'TLS certificate generation failed' }
& $openssl x509 -in $cert -noout -fingerprint -sha256 -dates
Write-Output 'Self-signed development certificate only. No system trust store or firewall settings changed.'
Write-Output 'A real phone must explicitly trust this certificate through supported OS/browser settings; do not bypass a certificate warning.'
foreach ($address in $addresses) { Write-Output ('LAN URL: https://' + $address + ':8788') }
