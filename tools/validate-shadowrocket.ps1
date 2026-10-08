[CmdletBinding()]
param(
    [string]$RulesRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'shadowrocket'),
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$rulesRootPath = (Resolve-Path -LiteralPath $RulesRoot).Path
$manifestPath = Join-Path $rulesRootPath 'manifest.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$expectedPaths = @($manifest.files.path | Sort-Object)
$actualPaths = @(Get-ChildItem -LiteralPath $rulesRootPath -File -Filter '*.list' | Select-Object -ExpandProperty Name | Sort-Object)

if (($expectedPaths -join "`n") -cne ($actualPaths -join "`n")) {
    throw 'The manifest file list does not match the generated .list files.'
}

foreach ($entry in $manifest.files) {
    $path = Join-Path $rulesRootPath $entry.path
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -cne $entry.sha256) {
        throw "SHA-256 mismatch: $($entry.path)"
    }

    $payload = @(Get-Content -LiteralPath $path | Where-Object { $_ -ne '' -and -not $_.StartsWith('#') })
    if ($payload.Count -ne $entry.rules) {
        throw "Rule count mismatch: $($entry.path) (manifest=$($entry.rules), actual=$($payload.Count))"
    }
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($ruleLine in $payload) {
        if (-not $seen.Add($ruleLine)) {
            throw "Duplicate rule found in $($entry.path): $ruleLine"
        }
    }

    if ($entry.kind -eq 'RULE-SET') {
        $invalid = @($payload | Where-Object { $_ -notmatch '^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD|DOMAIN-WILDCARD|IP-CIDR|IP-ASN|USER-AGENT),' })
        if ($invalid.Count -gt 0) {
            throw "Unsupported typed rule in $($entry.path): $($invalid[0])"
        }
    }
    elseif ($entry.kind -eq 'DOMAIN-SET') {
        $invalid = @($payload | Where-Object { $_ -match ',' -or $_ -match '\s' })
        if ($invalid.Count -gt 0) {
            throw "Invalid DOMAIN-SET entry in $($entry.path): $($invalid[0])"
        }
    }
    else {
        throw "Unknown manifest kind '$($entry.kind)' for $($entry.path)"
    }
}

$unsupported = @(rg -n '^(PROCESS-|IP-CIDR6|DOMAIN-REGEX),' $rulesRootPath 2>$null)
if ($unsupported.Count -gt 0) {
    throw "Unsupported Shadowrocket rules found: $($unsupported[0])"
}

if ($ConfigPath) {
    $configPathResolved = (Resolve-Path -LiteralPath $ConfigPath).Path
    $lines = Get-Content -LiteralPath $configPathResolved
    $proxyGroupStart = ($lines | Select-String '^\[Proxy Group\]$').LineNumber
    $ruleStart = ($lines | Select-String '^\[Rule\]$').LineNumber
    if (-not $proxyGroupStart -or -not $ruleStart) {
        throw 'The config is missing [Proxy Group] or [Rule].'
    }

    $policyNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($line in $lines[$proxyGroupStart..($ruleStart - 2)]) {
        if ($line -match '^(?<name>[^#=]+)=') { [void]$policyNames.Add($Matches.name.Trim()) }
    }
    foreach ($builtIn in @('DIRECT', 'REJECT', 'REJECT-NO-DROP')) { [void]$policyNames.Add($builtIn) }

    $remoteLines = @($lines | Where-Object { $_ -match '^(RULE-SET|DOMAIN-SET),' })
    foreach ($line in $remoteLines) {
        $parts = $line -split ','
        $url = [uri]$parts[1]
        $policy = $parts[2]
        if ($url.Host -cne 'raw.githubusercontent.com' -or $url.AbsolutePath -notlike '/keixhuiq/domains-and-ips/main/shadowrocket/*') {
            throw "Unexpected remote rule URL: $($url.AbsoluteUri)"
        }
        $localName = [IO.Path]::GetFileName($url.AbsolutePath)
        if (-not (Test-Path -LiteralPath (Join-Path $rulesRootPath $localName) -PathType Leaf)) {
            throw "Config references a missing local rule file: $localName"
        }
        if (-not $policyNames.Contains($policy)) {
            throw "Config references an unknown policy: $policy"
        }
    }
    if ($remoteLines.Count -ne 38) {
        throw "Expected 38 remote rule references, found $($remoteLines.Count)."
    }
}

Write-Host "Validated $($manifest.files.Count) rule files and $((($manifest.files | Measure-Object rules -Sum).Sum)) rules."
if ($ConfigPath) { Write-Host 'Validated 38 config references, local files, and policy targets.' }
