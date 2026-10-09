[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$ShadowrocketUpstreamRoot,
    [string]$OutputRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'shadowrocket')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$snapshotName = '20261008-live/post-deploy-v11'
$expectedUpstreamCommit = '036c097eb26c6a52c4f04ebcb6633043cb942669'
$sourceRootPath = (Resolve-Path -LiteralPath $SourceRoot).Path
$upstreamRootPath = (Resolve-Path -LiteralPath $ShadowrocketUpstreamRoot).Path
$utf8NoBom = [Text.UTF8Encoding]::new($false)

$actualUpstreamCommit = (& git -C $upstreamRootPath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualUpstreamCommit -cne $expectedUpstreamCommit) {
    throw "Expected Blackmatrix source at $expectedUpstreamCommit; found '$actualUpstreamCommit'."
}

$iosExtensions = @(
    @{ target = 'Apple-domain'; source = 'Apple/Apple.list'; types = @('USER-AGENT') }
    @{ target = 'Bahamut-domain'; source = 'Bahamut/Bahamut.list'; types = @('USER-AGENT') }
    @{ target = 'Bilibili-domain'; source = 'BiliBili/BiliBili.list'; types = @('USER-AGENT') }
    @{ target = 'China-domain'; source = 'ChinaMax/ChinaMax.list'; types = @('USER-AGENT') }
    @{ target = 'China-ip'; source = 'ChinaMax/ChinaMax.list'; types = @('IP-ASN') }
    @{ target = 'DisneyPlus-domain'; source = 'Disney/Disney.list'; types = @('USER-AGENT') }
    @{ target = 'Google-domain'; source = 'Google/Google.list'; types = @('USER-AGENT') }
    @{ target = 'HBO-domain'; source = 'HBO/HBO.list'; types = @('USER-AGENT') }
    @{ target = 'Meta-ip'; source = 'Facebook/Facebook.list'; types = @('IP-ASN') }
    @{ target = 'Microsoft-domain'; source = 'Microsoft/Microsoft.list'; types = @('USER-AGENT') }
    @{ target = 'MyTVSuper-domain'; source = 'myTVSUPER/myTVSUPER.list'; types = @('USER-AGENT') }
    @{ target = 'Netflix-domain'; source = 'Netflix/Netflix.list'; types = @('USER-AGENT') }
    @{ target = 'Spotify-domain'; source = 'Spotify/Spotify.list'; types = @('USER-AGENT') }
    @{ target = 'Telegram-ip'; source = 'Telegram/Telegram.list'; types = @('IP-ASN') }
    @{ target = 'YouTube-domain'; source = 'YouTube/YouTube.list'; types = @('USER-AGENT') }
)

$regexConversions = [Collections.Generic.List[object]]::new()
$logicalConversions = [Collections.Generic.List[object]]::new()
$compoundConversions = [Collections.Generic.List[object]]::new()
$iosOnlyExtensions = [Collections.Generic.List[object]]::new()
$sourceFiles = [ordered]@{}
$iosSourceFiles = [ordered]@{}
$manifestFiles = [Collections.Generic.List[object]]::new()
$outputMappings = [Collections.Generic.List[object]]::new()

function Add-UniqueRule {
    param(
        [Collections.Generic.List[string]]$List,
        [Collections.Generic.HashSet[string]]$Seen,
        [Parameter(Mandatory)][string]$Rule
    )
    if ($Seen.Add($Rule)) { $List.Add($Rule) }
}

function Get-PolicyForStem {
    param([Parameter(Mandatory)][string]$Stem)
    $service = $Stem -replace '-(domain|ip|port|process)$', ''
    switch ($service) {
        'block' { 'Block' }
        'direct' { 'Direct' }
        'Private' { 'Direct' }
        'China' { 'Direct' }
        'CustomProxy' { 'Proxies' }
        default { $service }
    }
}

function Convert-DomainRegex {
    param(
        [Parameter(Mandatory)][string]$SourceFile,
        [Parameter(Mandatory)][string]$Regex
    )

    $outputs = @()
    $quality = 'equivalent'
    $reason = ''

    if ($Regex -match '^\^\.\+\\\.(?<suffix>[A-Za-z0-9\\.-]+)\$$') {
        $suffix = $Matches.suffix -replace '\\\.', '.'
        $outputs = @("DOMAIN-SUFFIX,$suffix")
        $reason = 'Simple subdomain regex represented by an existing domain suffix.'
    }
    else {
        switch -Exact ($Regex) {
            '.+\.awsdns-cn-[0-9][0-9]\.(biz|com|net|top)$' {
                $outputs = @(
                    'DOMAIN-WILDCARD,*.awsdns-cn-*.biz',
                    'DOMAIN-WILDCARD,*.awsdns-cn-*.com',
                    'DOMAIN-WILDCARD,*.awsdns-cn-*.net',
                    'DOMAIN-WILDCARD,*.awsdns-cn-*.top'
                )
                $quality = 'conservative-approximation'
                $reason = 'Numeric and TLD alternatives represented with bounded wildcards.'
            }
            '.+\.awsdns-cn-[0-9][a-e0-9]\.cn$' {
                $outputs = @('DOMAIN-WILDCARD,*.awsdns-cn-*.cn')
                $quality = 'conservative-approximation'
                $reason = 'Character classes represented with a bounded wildcard.'
            }
            '(^|\.)turn[0-9]*\.' {
                $outputs = @('DOMAIN-KEYWORD,turn')
                $quality = 'broader-existing-rule'
                $reason = 'The existing local keyword rule already covers this TURN regex.'
            }
            '^(.+\.)*zh\.okaapps\.com$' {
                $outputs = @('DOMAIN-SUFFIX,zh.okaapps.com')
                $reason = 'Apex and subdomains map to DOMAIN-SUFFIX.'
            }
            '^.+-mihayo\.akamaized\.net$' {
                $outputs = @('DOMAIN-WILDCARD,*-mihayo.akamaized.net')
                $quality = 'conservative-approximation'
                $reason = 'Regular expression represented with a wildcard.'
            }
            '^cdn\d-epicgames-\d+\.file\.myqcloud\.com$' {
                $outputs = @('DOMAIN-WILDCARD,cdn*-epicgames-*.file.myqcloud.com')
                $quality = 'conservative-approximation'
                $reason = 'Numeric tokens represented with wildcards.'
            }
            '^epicgames-download\d-\d+\.file\.myqcloud\.com$' {
                $outputs = @('DOMAIN-WILDCARD,epicgames-download*-*.file.myqcloud.com')
                $quality = 'conservative-approximation'
                $reason = 'Numeric tokens represented with wildcards.'
            }
            '^r+[0-9]+(---|\.)sn-(2x3|ni5|j5o)\w{5}\.googlevideo\.com$' {
                $outputs = @('DOMAIN-WILDCARD,r*---sn-*.googlevideo.com', 'DOMAIN-WILDCARD,r*.sn-*.googlevideo.com')
                $quality = 'conservative-approximation'
                $reason = 'Alternation represented with two wildcard rules.'
            }
            '^r+[0-9]+(---|\.)sn-(2x3|ni5|j5o)\w{5}\.xn--ngstr-lra8j\.com$' {
                $outputs = @('DOMAIN-WILDCARD,r*---sn-*.xn--ngstr-lra8j.com', 'DOMAIN-WILDCARD,r*.sn-*.xn--ngstr-lra8j.com')
                $quality = 'conservative-approximation'
                $reason = 'Alternation represented with two wildcard rules.'
            }
            '^chatgpt-async-webps-prod-\S+-\d+\.webpubsub\.azure\.com$' {
                $outputs = @('DOMAIN-WILDCARD,chatgpt-async-webps-prod-*-*.webpubsub.azure.com')
                $quality = 'conservative-approximation'
                $reason = 'Character classes represented with wildcards.'
            }
            default { throw "No audited Shadowrocket conversion exists for regex '$Regex' in $SourceFile." }
        }
    }

    $regexConversions.Add([ordered]@{
        source = $SourceFile
        input = $Regex
        output = $outputs
        quality = $quality
        note = $reason
    })
    return $outputs
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
Get-ChildItem -LiteralPath $OutputRoot -File -Filter '*.list' -ErrorAction SilentlyContinue | Remove-Item -Force

$jsonFiles = @(Get-ChildItem -LiteralPath $sourceRootPath -File -Filter '*.json' | Sort-Object Name)
foreach ($sourceFile in $jsonFiles) {
    $sourceName = $sourceFile.Name
    $stem = [IO.Path]::GetFileNameWithoutExtension($sourceName)
    $sourceFiles[$sourceName] = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()

    if ($sourceName -eq 'direct-process.json') { continue }

    $rules = [Collections.Generic.List[string]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $document = Get-Content -Raw -LiteralPath $sourceFile.FullName | ConvertFrom-Json

    foreach ($ruleObject in @($document.rules)) {
        if ($ruleObject.PSObject.Properties.Name -contains 'type' -and $ruleObject.type -eq 'logical') {
            if ($sourceName -eq 'Google-domain.json' -and $ruleObject.mode -eq 'and') {
                Add-UniqueRule -List $rules -Seen $seen -Rule 'DOMAIN-SUFFIX,google.com'
                $logicalConversions.Add([ordered]@{
                    source = $sourceName
                    output = @('DOMAIN-SUFFIX,google.com')
                    companionConfigRule = 'DOMAIN-SUFFIX,storage.cloud.google.com,✈️Final,force-remote-dns'
                    note = 'The updated config places the inverted hostname exception before this rule set.'
                })
                continue
            }
            throw "Unsupported logical rule in $sourceName."
        }

        $hasNetwork = $ruleObject.PSObject.Properties.Name -contains 'network'
        $hasPort = $ruleObject.PSObject.Properties.Name -contains 'port'
        if ($hasNetwork -or $hasPort) {
            if ($sourceName -ne 'block-port.json' -or $ruleObject.network -ne 'udp' -or -not $hasPort) {
                throw "Unsupported network/port predicate in $sourceName."
            }
            foreach ($port in @($ruleObject.port)) {
                Add-UniqueRule -List $rules -Seen $seen -Rule "AND,((PROTOCOL,UDP),(DST-PORT,$port))"
            }
            $compoundConversions.Add([ordered]@{
                source = $sourceName
                input = 'network=udp AND port in list'
                outputCount = @($ruleObject.port).Count
                quality = 'equivalent'
            })
            continue
        }

        foreach ($property in $ruleObject.PSObject.Properties) {
            $key = $property.Name
            if ($key -eq 'domain_regex') {
                foreach ($regex in @($property.Value)) {
                    foreach ($converted in @(Convert-DomainRegex -SourceFile $sourceName -Regex $regex)) {
                        Add-UniqueRule -List $rules -Seen $seen -Rule $converted
                    }
                }
                continue
            }

            if ($key -notin @('domain', 'domain_suffix', 'domain_keyword', 'ip_cidr', 'ip_cidr6')) {
                throw "Unsupported rule key '$key' in $sourceName."
            }

            foreach ($valueObject in @($property.Value)) {
                $value = [string]$valueObject
                switch ($key) {
                    'domain' { Add-UniqueRule -List $rules -Seen $seen -Rule "DOMAIN,$value" }
                    'domain_suffix' { Add-UniqueRule -List $rules -Seen $seen -Rule "DOMAIN-SUFFIX,$value" }
                    'domain_keyword' { Add-UniqueRule -List $rules -Seen $seen -Rule "DOMAIN-KEYWORD,$value" }
                    'ip_cidr' { Add-UniqueRule -List $rules -Seen $seen -Rule "IP-CIDR,$value,no-resolve" }
                    'ip_cidr6' { Add-UniqueRule -List $rules -Seen $seen -Rule "IP-CIDR,$value,no-resolve" }
                }
            }
        }
    }

    foreach ($extension in @($iosExtensions | Where-Object target -eq $stem)) {
        $relativeSource = $extension.source
        $iosSourcePath = Join-Path $upstreamRootPath ($relativeSource -replace '/', [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $iosSourcePath -PathType Leaf)) {
            throw "Missing pinned iOS extension source: $iosSourcePath"
        }
        $iosSourceFiles[$relativeSource] = (Get-FileHash -LiteralPath $iosSourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $added = 0
        foreach ($line in Get-Content -LiteralPath $iosSourcePath) {
            $type = ($line -split ',', 2)[0]
            if ($type -in $extension.types) {
                $before = $rules.Count
                Add-UniqueRule -List $rules -Seen $seen -Rule $line
                if ($rules.Count -gt $before) { $added++ }
            }
        }
        $iosOnlyExtensions.Add([ordered]@{
            target = "$stem.list"
            source = $relativeSource
            types = $extension.types
            added = $added
        })
    }

    $outputPath = Join-Path $OutputRoot "$stem.list"
    $body = @(
        "# NAME: $stem"
        '# FORMAT: Shadowrocket RULE-SET'
        "# SOURCE: $sourceName"
        "# SOURCE-SNAPSHOT: $snapshotName"
        "# IOS-UPSTREAM: blackmatrix7/ios_rule_script@$expectedUpstreamCommit"
        "# RULES: $($rules.Count)"
    )
    if ($rules.Count -gt 0) { $body += @('') + @($rules) }
    [IO.File]::WriteAllText($outputPath, (($body -join "`n") + "`n"), $utf8NoBom)

    $manifestFiles.Add([ordered]@{
        path = [IO.Path]::GetFileName($outputPath)
        source = $sourceName
        policy = Get-PolicyForStem -Stem $stem
        kind = 'RULE-SET'
        rules = $rules.Count
        sha256 = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
    })
    $outputMappings.Add([ordered]@{
        source = $sourceName
        output = "$stem.list"
        policy = Get-PolicyForStem -Stem $stem
    })
}

$processDocument = Get-Content -Raw -LiteralPath (Join-Path $sourceRootPath 'direct-process.json') | ConvertFrom-Json
$processCount = 0
foreach ($ruleObject in @($processDocument.rules)) {
    if ($ruleObject.PSObject.Properties.Name -contains 'process_name') { $processCount += @($ruleObject.process_name).Count }
}

if (@($sourceFiles.Keys).Count -ne $jsonFiles.Count) { throw 'Not every production JSON source was inventoried.' }

$generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$report = [ordered]@{
    schemaVersion = 2
    sourceSnapshot = $snapshotName
    iosUpstreamCommit = $expectedUpstreamCommit
    generatedAt = $generatedAt
    naming = 'Each production JSON maps to the identically named .list; direct-process.json is the only omitted output.'
    sourceFiles = $sourceFiles
    iosSourceFiles = $iosSourceFiles
    outputMappings = $outputMappings
    intentionalExclusions = @(
        [ordered]@{
            source = 'direct-process.json'
            count = $processCount
            reason = 'PROCESS-NAME is not supported by Shadowrocket.'
        }
    )
    regexConversions = $regexConversions
    logicalConversions = $logicalConversions
    compoundConversions = $compoundConversions
    iosOnlyExtensions = $iosOnlyExtensions
}
$reportJson = (($report | ConvertTo-Json -Depth 12) -replace "`r`n", "`n") + "`n"
[IO.File]::WriteAllText((Join-Path $OutputRoot 'conversion-report.json'), $reportJson, $utf8NoBom)

$manifest = [ordered]@{
    schemaVersion = 2
    sourceSnapshot = $snapshotName
    iosUpstreamCommit = $expectedUpstreamCommit
    generatedAt = $generatedAt
    files = $manifestFiles
}
$manifestJson = (($manifest | ConvertTo-Json -Depth 8) -replace "`r`n", "`n") + "`n"
[IO.File]::WriteAllText((Join-Path $OutputRoot 'manifest.json'), $manifestJson, $utf8NoBom)

Write-Host "Generated $($manifestFiles.Count) one-to-one Shadowrocket rule files in $OutputRoot"
