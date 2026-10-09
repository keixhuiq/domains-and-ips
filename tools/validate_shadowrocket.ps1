[CmdletBinding()]
param(
    [string]$RulesRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'shadowrocket'),
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$rulesRootPath = (Resolve-Path -LiteralPath $RulesRoot).Path
$manifest = Get-Content -Raw -LiteralPath (Join-Path $rulesRootPath 'manifest.json') | ConvertFrom-Json
$expectedPaths = @($manifest.files.path | Sort-Object)
$actualPaths = @(Get-ChildItem -LiteralPath $rulesRootPath -File -Filter '*.list' | Select-Object -ExpandProperty Name | Sort-Object)
if (($expectedPaths -join "`n") -cne ($actualPaths -join "`n")) {
    throw 'The manifest file list does not match the generated .list files.'
}
if ($actualPaths.Count -ne 51) { throw "Expected 51 one-to-one .list files, found $($actualPaths.Count)." }

foreach ($entry in $manifest.files) {
    $path = Join-Path $rulesRootPath $entry.path
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -cne $entry.sha256) { throw "SHA-256 mismatch: $($entry.path)" }

    $payload = @(Get-Content -LiteralPath $path | Where-Object { $_ -ne '' -and -not $_.StartsWith('#') })
    if ($payload.Count -ne $entry.rules) {
        throw "Rule count mismatch: $($entry.path) (manifest=$($entry.rules), actual=$($payload.Count))"
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($ruleLine in $payload) {
        if (-not $seen.Add($ruleLine)) { throw "Duplicate rule in $($entry.path): $ruleLine" }
        if ($ruleLine -notmatch '^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD|DOMAIN-WILDCARD|IP-CIDR|IP-ASN|USER-AGENT|AND),') {
            throw "Unsupported typed rule in $($entry.path): $ruleLine"
        }
        if ($ruleLine -match '^(PROCESS-|IP-CIDR6|DOMAIN-REGEX),') {
            throw "Unsupported Shadowrocket rule in $($entry.path): $ruleLine"
        }
    }
}

$sourceNames = @($manifest.files.source | Sort-Object)
$expectedSources = @(Get-Content -Raw -LiteralPath (Join-Path $rulesRootPath 'conversion-report.json') | ConvertFrom-Json | Select-Object -ExpandProperty outputMappings | Select-Object -ExpandProperty source | Sort-Object)
if (($sourceNames -join "`n") -cne ($expectedSources -join "`n")) { throw 'Manifest/source mapping mismatch.' }
if ($sourceNames -contains 'direct-process.json') { throw 'direct-process.json must not have a Shadowrocket output.' }

if ($ConfigPath) {
    $configPathResolved = (Resolve-Path -LiteralPath $ConfigPath).Path
    $lines = Get-Content -LiteralPath $configPathResolved
    $proxyGroupStart = ($lines | Select-String '^\[Proxy Group\]$').LineNumber
    $ruleStart = ($lines | Select-String '^\[Rule\]$').LineNumber
    if (-not $proxyGroupStart -or -not $ruleStart) { throw 'The config is missing [Proxy Group] or [Rule].' }

    $groupNames = [Collections.Generic.List[string]]::new()
    foreach ($line in $lines[$proxyGroupStart..($ruleStart - 2)]) {
        if ($line -match '^(?<name>[^#=]+)=') { $groupNames.Add($Matches.name.Trim()) }
    }
    $expectedProductionGroups = @(
        'SpecialTools','Claude','OpenAI','LINE','X','TikTok','Netflix','Crunchyroll','ABEMA','U-NEXT','Spotify','Pixiv',
        'BookWalker','DisneyPlus','HBO','Bahamut','MyTVSuper','YouTube','Steam','Epic','Xbox','PlayStation','Google',
        'Amazon','NVIDIA','Scholar','Crypto','Telegram','Meta','Bilibili','Microsoft','Apple','Proxies','Direct','Block'
    )
    $expectedGroupOrder = @($expectedProductionGroups) + '✈️Final'
    if (($groupNames -join "`n") -cne ($expectedGroupOrder -join "`n")) {
        throw "Policy group names or order do not exactly match the production topology. Actual: $($groupNames -join ', ')"
    }
    foreach ($deprecated in @('Abema','BOOKWALKERJP','BOOKWALKERTW','🎯Direct')) {
        if ($groupNames -ccontains $deprecated) { throw "Deprecated policy group remains: $deprecated" }
    }
    if ($groupNames.Count -ne 36) { throw "Expected 35 production groups plus Final, found $($groupNames.Count)." }

    $policyNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($name in $groupNames) { [void]$policyNames.Add($name) }
    foreach ($builtIn in @('DIRECT','REJECT','REJECT-NO-DROP')) { [void]$policyNames.Add($builtIn) }

    $remoteLines = @($lines | Where-Object { $_ -match '^RULE-SET,' })
    if ($remoteLines.Count -ne 51) { throw "Expected 51 remote RULE-SET references, found $($remoteLines.Count)." }
    $referencedFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($line in $remoteLines) {
        $parts = $line -split ','
        $url = [uri]$parts[1]
        $policy = $parts[2]
        if ($url.Host -cne 'raw.githubusercontent.com' -or $url.AbsolutePath -notlike '/keixhuiq/domains-and-ips/main/shadowrocket/*') {
            throw "Unexpected remote rule URL: $($url.AbsoluteUri)"
        }
        $localName = [IO.Path]::GetFileName($url.AbsolutePath)
        if (-not (Test-Path -LiteralPath (Join-Path $rulesRootPath $localName) -PathType Leaf)) {
            throw "Config references a missing rule file: $localName"
        }
        if (-not $referencedFiles.Add($localName)) { throw "Duplicate config reference: $localName" }
        if (-not $policyNames.Contains($policy)) { throw "Config references an unknown or noncanonical policy: $policy" }
    }
    if (($referencedFiles | Sort-Object) -join "`n" -cne ($actualPaths -join "`n")) {
        throw 'The config does not reference every generated .list exactly once.'
    }
    if (@($lines | Where-Object { $_ -match '^DOMAIN-SET,' }).Count -gt 0) { throw 'DOMAIN-SET references remain in the config.' }
}

$totalRules = (($manifest.files | Measure-Object rules -Sum).Sum)
Write-Host "Validated 51 one-to-one rule files and $totalRules rules."
if ($ConfigPath) { Write-Host 'Validated 51 references and 35 production policy groups plus Final.' }
