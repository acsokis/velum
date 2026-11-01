function Test-VelumRtxPackage([string]$ProjectRoot) {
    try {
        $target = Join-Path $ProjectRoot 'build-rtx'
        $marker = Get-Content -LiteralPath (Join-Path $target 'validated.json') -Raw | ConvertFrom-Json
        if ($marker.renderer -ne 'vulkan') { return $false }
        if ((Get-FileHash -LiteralPath (Join-Path $target 'VELUM.exe')).Hash -ne $marker.executableSha256) { return $false }
        if ((Get-FileHash -LiteralPath (Join-Path $target 'VELUM.pck')).Hash -ne $marker.packageSha256) { return $false }
        if ((Get-FileHash -LiteralPath (Join-Path $ProjectRoot 'build\VELUM.pck')).Hash -ne $marker.packageSha256) { return $false }
        $manifest = Get-Content -LiteralPath (Join-Path $target 'runtime-integrity.json') -Raw | ConvertFrom-Json
        foreach ($entry in $manifest) {
            if ([IO.Path]::GetFileName($entry.Name) -ne $entry.Name) { return $false }
            if ((Get-FileHash -LiteralPath (Join-Path $target $entry.Name)).Hash -ne $entry.Hash) { return $false }
        }
        return $true
    } catch { return $false }
}
