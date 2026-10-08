[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SourceRoot,

    [Parameter(Mandatory)]
    [string]$ShadowrocketUpstreamRoot,

    [string]$OutputRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'shadowrocket')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$snapshotName = '20261008-live/post-deploy-v11'
$expectedUpstreamCommit = '036c097eb26c6a52c4f04ebcb6633043cb942669'
$sourceRootPath = (Resolve-Path -LiteralPath $SourceRoot).Path
$upstreamRootPath = (Resolve-Path -LiteralPath $ShadowrocketUpstreamRoot).Path
$actualUpstreamCommit = (& git -C $upstreamRootPath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualUpstreamCommit -cne $expectedUpstreamCommit) {
    throw "Expected Blackmatrix Shadowrocket source at commit $expectedUpstreamCommit; found '$actualUpstreamCommit'."
}
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

$serviceSources = [ordered]@{
    'ABEMA'        = @('ABEMA-domain.json')
    'Amazon'       = @('Amazon-domain.json')
    'Apple'        = @('Apple-domain.json', 'Apple-ip.json')
    'Bahamut'      = @('Bahamut-domain.json')
    'Bilibili'     = @('Bilibili-domain.json', 'Bilibili-ip.json')
    'BookWalkerJP' = @('BookWalker-domain.json')
    'BookWalkerTW' = @('BookWalker-domain.json')
    'Block'        = @('block-domain.json', 'block-ip.json')
    'China'        = @('China-domain.json', 'China-ip.json')
    'Claude'       = @('Claude-domain.json')
    'Crunchyroll'  = @('Crunchyroll-domain.json')
    'Crypto'       = @('Crypto-domain.json')
    'CustomProxy'  = @('CustomProxy-domain.json', 'CustomProxy-ip.json')
    'Direct'       = @('direct-domain.json', 'direct-ip.json')
    'DisneyPlus'   = @('DisneyPlus-domain.json')
    'Epic'         = @('Epic-domain.json')
    'Google'       = @('Google-domain.json', 'Google-ip.json')
    'HBO'          = @('HBO-domain.json')
    'LINE'         = @('LINE-domain.json', 'LINE-ip.json')
    'Meta'         = @('Meta-domain.json', 'Meta-ip.json')
    'Microsoft'    = @('Microsoft-domain.json')
    'MyTVSuper'    = @('MyTVSuper-domain.json')
    'Netflix'      = @('Netflix-domain.json', 'Netflix-ip.json')
    'NVIDIA'       = @('NVIDIA-domain.json')
    'OpenAI'       = @('OpenAI-domain.json')
    'Pixiv'        = @('Pixiv-domain.json')
    'PlayStation'  = @('PlayStation-domain.json')
    'Private'      = @('Private-ip.json')
    'Scholar'      = @('Scholar-domain.json')
    'Spotify'      = @('Spotify-domain.json', 'Spotify-ip.json')
    'Steam'        = @('Steam-domain.json')
    'Telegram'     = @('Telegram-domain.json', 'Telegram-ip.json')
    'TikTok'       = @('TikTok-domain.json')
    'UNEXT'        = @('U-NEXT-domain.json')
    'X'            = @('X-domain.json', 'X-ip.json')
    'Xbox'         = @('Xbox-domain.json')
    'YouTube'      = @('YouTube-domain.json', 'YouTube-ip.json')
}

$splitDomainServices = @('Apple', 'China', 'CustomProxy')
$iosExtensionSources = [ordered]@{
    'Apple'       = @('Apple/Apple.list')
    'Bahamut'     = @('Bahamut/Bahamut.list')
    'Bilibili'    = @('BiliBili/BiliBili.list')
    'China'       = @('ChinaMax/ChinaMax.list')
    'DisneyPlus'  = @('Disney/Disney.list')
    'Google'      = @('Google/Google.list')
    'HBO'         = @('HBO/HBO.list')
    'Meta'        = @('Facebook/Facebook.list', 'Instagram/Instagram.list', 'Whatsapp/Whatsapp.list')
    'Microsoft'   = @('Microsoft/Microsoft.list')
    'MyTVSuper'   = @('myTVSUPER/myTVSUPER.list')
    'Netflix'     = @('Netflix/Netflix.list')
    'Spotify'     = @('Spotify/Spotify.list')
    'Telegram'    = @('Telegram/Telegram.list')
    'YouTube'     = @('YouTube/YouTube.list')
}
$portableKeys = @('domain', 'domain_suffix', 'domain_keyword', 'ip_cidr', 'ip_cidr6')
$rulesByService = [ordered]@{}
$regexConversions = [System.Collections.Generic.List[object]]::new()
$logicalConversions = [System.Collections.Generic.List[object]]::new()
$iosOnlyExtensions = [System.Collections.Generic.List[object]]::new()
$sourceFiles = [ordered]@{}
$iosSourceFiles = [ordered]@{}

function Add-UniqueRule {
    param(
        [System.Collections.Generic.List[string]]$List,
        [System.Collections.Generic.HashSet[string]]$Seen,
        [Parameter(Mandatory)][string]$Rule
    )

    if ($Seen.Add($Rule)) {
        $List.Add($Rule)
    }
}

function Convert-DomainRegex {
    param(
        [Parameter(Mandatory)][string]$Service,
        [Parameter(Mandatory)][string]$SourceFile,
        [Parameter(Mandatory)][string]$Regex
    )

    $outputs = @()
    $quality = 'equivalent'
    $reason = ''

    if ($Regex -match '^\^\.\+\\\.(?<suffix>[A-Za-z0-9\\.-]+)\$$') {
        $suffix = $Matches.suffix -replace '\\\.', '.'
        $outputs = @("DOMAIN-SUFFIX,$suffix")
        $reason = 'Simple subdomain regex expressed as a domain suffix; the source already includes the apex suffix.'
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
                $reason = 'The two-digit and TLD alternatives are represented with wildcard rules.'
            }
            '.+\.awsdns-cn-[0-9][a-e0-9]\.cn$' {
                $outputs = @('DOMAIN-WILDCARD,*.awsdns-cn-*.cn')
                $quality = 'conservative-approximation'
                $reason = 'The two-character class is represented with a wildcard.'
            }
            '(^|\.)turn[0-9]*\.' {
                $outputs = @('DOMAIN-KEYWORD,turn')
                $quality = 'broader-existing-rule'
                $reason = 'The existing local keyword rule already covers this TURN label regex.'
            }
            '^(.+\.)*zh\.okaapps\.com$' {
                $outputs = @('DOMAIN-SUFFIX,zh.okaapps.com')
                $reason = 'Apex and all subdomains map exactly to DOMAIN-SUFFIX.'
            }
            '^.+-mihayo\.akamaized\.net$' {
                $outputs = @('DOMAIN-WILDCARD,*-mihayo.akamaized.net')
                $quality = 'conservative-approximation'
                $reason = 'Shadowrocket wildcard replaces the source regular expression.'
            }
            '^cdn\d-epicgames-\d+\.file\.myqcloud\.com$' {
                $outputs = @('DOMAIN-WILDCARD,cdn*-epicgames-*.file.myqcloud.com')
                $quality = 'conservative-approximation'
                $reason = 'Numeric regex tokens are represented with wildcards.'
            }
            '^epicgames-download\d-\d+\.file\.myqcloud\.com$' {
                $outputs = @('DOMAIN-WILDCARD,epicgames-download*-*.file.myqcloud.com')
                $quality = 'conservative-approximation'
                $reason = 'Numeric regex tokens are represented with wildcards.'
            }
            '^r+[0-9]+(---|\.)sn-(2x3|ni5|j5o)\w{5}\.googlevideo\.com$' {
                $outputs = @(
                    'DOMAIN-WILDCARD,r*---sn-*.googlevideo.com',
                    'DOMAIN-WILDCARD,r*.sn-*.googlevideo.com'
                )
                $quality = 'conservative-approximation'
                $reason = 'Alternation and character classes are represented with two wildcard rules.'
            }
            '^r+[0-9]+(---|\.)sn-(2x3|ni5|j5o)\w{5}\.xn--ngstr-lra8j\.com$' {
                $outputs = @(
                    'DOMAIN-WILDCARD,r*---sn-*.xn--ngstr-lra8j.com',
                    'DOMAIN-WILDCARD,r*.sn-*.xn--ngstr-lra8j.com'
                )
                $quality = 'conservative-approximation'
                $reason = 'Alternation and character classes are represented with two wildcard rules.'
            }
            '^chatgpt-async-webps-prod-\S+-\d+\.webpubsub\.azure\.com$' {
                $outputs = @('DOMAIN-WILDCARD,chatgpt-async-webps-prod-*-*.webpubsub.azure.com')
                $quality = 'conservative-approximation'
                $reason = 'Character classes are represented with wildcards.'
            }
            default {
                throw "No audited Shadowrocket conversion exists for regex '$Regex' in $SourceFile."
            }
        }
    }

    $regexConversions.Add([ordered]@{
        service = $Service
        source = $SourceFile
        input = $Regex
        output = $outputs
        quality = $quality
        note = $reason
    })
    return $outputs
}

foreach ($service in $serviceSources.Keys) {
    $typed = [System.Collections.Generic.List[string]]::new()
    # USER-AGENT matching can be case-sensitive, so typed rules are deduplicated byte-for-byte.
    $typedSeen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $domainSet = [System.Collections.Generic.List[string]]::new()
    $domainSeen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($sourceName in $serviceSources[$service]) {
        $sourcePath = Join-Path $sourceRootPath $sourceName
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Missing production rule source: $sourcePath"
        }

        if (-not $sourceFiles.Contains($sourceName)) {
            $sourceFiles[$sourceName] = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
        }

        $document = Get-Content -Raw -LiteralPath $sourcePath | ConvertFrom-Json
        foreach ($ruleObject in @($document.rules)) {
            if ($ruleObject.PSObject.Properties.Name -contains 'type' -and $ruleObject.type -eq 'logical') {
                if ($service -eq 'Google' -and $ruleObject.mode -eq 'and') {
                    Add-UniqueRule -List $typed -Seen $typedSeen -Rule 'DOMAIN-SUFFIX,google.com'
                    $logicalConversions.Add([ordered]@{
                        service = 'Google'
                        source = $sourceName
                        input = $ruleObject
                        output = @('DOMAIN-SUFFIX,google.com')
                        companionConfigRule = 'DOMAIN-SUFFIX,storage.cloud.google.com,FINAL-POLICY'
                        note = 'Shadowrocket list format cannot preserve the nested inverted predicate; the updated config places the excluded hostname before this rule set.'
                    })
                    continue
                }
                throw "Unsupported logical rule in $sourceName for $service."
            }

            foreach ($property in $ruleObject.PSObject.Properties) {
                $key = $property.Name
                if ($key -eq 'domain_regex') {
                    foreach ($regex in @($property.Value)) {
                        foreach ($converted in @(Convert-DomainRegex -Service $service -SourceFile $sourceName -Regex $regex)) {
                            Add-UniqueRule -List $typed -Seen $typedSeen -Rule $converted
                        }
                    }
                    continue
                }

                if ($key -notin $portableKeys) {
                    throw "Unsupported rule key '$key' in $sourceName for $service."
                }

                foreach ($valueObject in @($property.Value)) {
                    $value = [string]$valueObject

                    if ($service -eq 'BookWalkerJP' -and $value -notin @('bookwalker.jp', 'bookwalker.com')) {
                        continue
                    }
                    if ($service -eq 'BookWalkerTW' -and $value -ne 'bookwalker.com.tw') {
                        continue
                    }

                    if ($service -in $splitDomainServices -and $key -in @('domain', 'domain_suffix')) {
                        $domainValue = if ($key -eq 'domain_suffix') { ".$value" } else { $value }
                        Add-UniqueRule -List $domainSet -Seen $domainSeen -Rule $domainValue
                        continue
                    }

                    switch ($key) {
                        'domain'         { Add-UniqueRule -List $typed -Seen $typedSeen -Rule "DOMAIN,$value" }
                        'domain_suffix'  { Add-UniqueRule -List $typed -Seen $typedSeen -Rule "DOMAIN-SUFFIX,$value" }
                        'domain_keyword' { Add-UniqueRule -List $typed -Seen $typedSeen -Rule "DOMAIN-KEYWORD,$value" }
                        'ip_cidr'        { Add-UniqueRule -List $typed -Seen $typedSeen -Rule "IP-CIDR,$value,no-resolve" }
                        'ip_cidr6'       { Add-UniqueRule -List $typed -Seen $typedSeen -Rule "IP-CIDR,$value,no-resolve" }
                    }
                }
            }
        }
    }

    if ($iosExtensionSources.Contains($service)) {
        foreach ($relativeSource in $iosExtensionSources[$service]) {
            $iosSourcePath = Join-Path $upstreamRootPath ($relativeSource -replace '/', [IO.Path]::DirectorySeparatorChar)
            if (-not (Test-Path -LiteralPath $iosSourcePath -PathType Leaf)) {
                throw "Missing pinned iOS extension source: $iosSourcePath"
            }
            $iosSourceFiles[$relativeSource] = (Get-FileHash -LiteralPath $iosSourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
            $sourceCounts = [ordered]@{ 'USER-AGENT' = 0; 'IP-ASN' = 0 }
            foreach ($line in Get-Content -LiteralPath $iosSourcePath) {
                if ($line -match '^(USER-AGENT|IP-ASN),') {
                    $type = ($line -split ',', 2)[0]
                    Add-UniqueRule -List $typed -Seen $typedSeen -Rule $line
                    $sourceCounts[$type]++
                }
            }
            if (($sourceCounts['USER-AGENT'] + $sourceCounts['IP-ASN']) -gt 0) {
                $iosOnlyExtensions.Add([ordered]@{
                    service = $service
                    source = $relativeSource
                    userAgent = $sourceCounts['USER-AGENT']
                    ipAsn = $sourceCounts['IP-ASN']
                })
            }
        }
    }

    $rulesByService[$service] = [ordered]@{
        typed = $typed
        domainSet = $domainSet
    }
}

$processSourcePath = Join-Path $sourceRootPath 'direct-process.json'
$blockPortSourcePath = Join-Path $sourceRootPath 'block-port.json'
foreach ($excludedPath in @($processSourcePath, $blockPortSourcePath)) {
    if (-not (Test-Path -LiteralPath $excludedPath -PathType Leaf)) {
        throw "Missing intentionally excluded production rule source: $excludedPath"
    }
    $excludedName = [IO.Path]::GetFileName($excludedPath)
    $sourceFiles[$excludedName] = (Get-FileHash -LiteralPath $excludedPath -Algorithm SHA256).Hash.ToLowerInvariant()
}

$processDocument = Get-Content -Raw -LiteralPath $processSourcePath | ConvertFrom-Json
$processCount = 0
foreach ($ruleObject in @($processDocument.rules)) {
    if ($ruleObject.PSObject.Properties.Name -contains 'process_name') {
        $processCount += @($ruleObject.process_name).Count
    }
}
$blockPortDocument = Get-Content -Raw -LiteralPath $blockPortSourcePath | ConvertFrom-Json
$blockPortCount = 0
foreach ($ruleObject in @($blockPortDocument.rules)) {
    if ($ruleObject.PSObject.Properties.Name -contains 'port') {
        $blockPortCount += @($ruleObject.port).Count
    }
}

$allSnapshotFiles = @(Get-ChildItem -LiteralPath $sourceRootPath -File -Filter '*.json' | Select-Object -ExpandProperty Name | Sort-Object)
$coveredSnapshotFiles = @($sourceFiles.Keys | Sort-Object)
if (($allSnapshotFiles -join "`n") -cne ($coveredSnapshotFiles -join "`n")) {
    $missingCoverage = @($allSnapshotFiles | Where-Object { $_ -notin $coveredSnapshotFiles })
    $unknownCoverage = @($coveredSnapshotFiles | Where-Object { $_ -notin $allSnapshotFiles })
    throw "Snapshot coverage mismatch. Unmapped: $($missingCoverage -join ', '); missing: $($unknownCoverage -join ', ')"
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
Get-ChildItem -LiteralPath $OutputRoot -File -Filter '*.list' -ErrorAction SilentlyContinue | Remove-Item -Force

$manifestFiles = [System.Collections.Generic.List[object]]::new()
foreach ($service in $rulesByService.Keys) {
    $entry = $rulesByService[$service]
    $typedPath = Join-Path $OutputRoot "$service.list"
    $typedBody = @(
        "# NAME: $service"
        '# FORMAT: Shadowrocket RULE-SET'
        "# SOURCE-SNAPSHOT: $snapshotName"
        "# IOS-UPSTREAM: blackmatrix7/ios_rule_script@$expectedUpstreamCommit"
        "# RULES: $($entry.typed.Count)"
        ''
    ) + @($entry.typed)
    [IO.File]::WriteAllText($typedPath, (($typedBody -join "`n") + "`n"), $utf8NoBom)
    $manifestFiles.Add([ordered]@{
        path = [IO.Path]::GetFileName($typedPath)
        kind = 'RULE-SET'
        rules = $entry.typed.Count
        sha256 = (Get-FileHash -LiteralPath $typedPath -Algorithm SHA256).Hash.ToLowerInvariant()
    })

    if ($entry.domainSet.Count -gt 0) {
        $domainPath = Join-Path $OutputRoot "${service}_Domain.list"
        $domainBody = @(
            "# NAME: $service"
            '# FORMAT: Shadowrocket DOMAIN-SET'
            "# SOURCE-SNAPSHOT: $snapshotName"
            "# IOS-UPSTREAM: blackmatrix7/ios_rule_script@$expectedUpstreamCommit"
            "# RULES: $($entry.domainSet.Count)"
            ''
        ) + @($entry.domainSet)
        [IO.File]::WriteAllText($domainPath, (($domainBody -join "`n") + "`n"), $utf8NoBom)
        $manifestFiles.Add([ordered]@{
            path = [IO.Path]::GetFileName($domainPath)
            kind = 'DOMAIN-SET'
            rules = $entry.domainSet.Count
            sha256 = (Get-FileHash -LiteralPath $domainPath -Algorithm SHA256).Hash.ToLowerInvariant()
        })
    }
}

$report = [ordered]@{
    schemaVersion = 1
    sourceSnapshot = $snapshotName
    iosUpstreamCommit = $expectedUpstreamCommit
    generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    sourceFiles = $sourceFiles
    iosSourceFiles = $iosSourceFiles
    intentionalExclusions = @(
        [ordered]@{
            source = 'direct-process.json'
            count = $processCount
            reason = 'PROCESS-NAME is not supported by Shadowrocket and was explicitly excluded.'
        },
        [ordered]@{
            source = 'block-port.json'
            count = $blockPortCount
            reason = 'The sing-box network=udp AND port-list predicate has no lossless standalone Shadowrocket RULE-SET conversion.'
        }
    )
    regexConversions = $regexConversions
    logicalConversions = $logicalConversions
    iosOnlyExtensions = $iosOnlyExtensions
}
[IO.File]::WriteAllText(
    (Join-Path $OutputRoot 'conversion-report.json'),
    (($report | ConvertTo-Json -Depth 12) + "`n"),
    $utf8NoBom
)

$manifest = [ordered]@{
    schemaVersion = 1
    sourceSnapshot = $snapshotName
    iosUpstreamCommit = $expectedUpstreamCommit
    generatedAt = $report.generatedAt
    files = $manifestFiles
}
[IO.File]::WriteAllText(
    (Join-Path $OutputRoot 'manifest.json'),
    (($manifest | ConvertTo-Json -Depth 6) + "`n"),
    $utf8NoBom
)

Write-Host "Generated $($manifestFiles.Count) Shadowrocket list files in $OutputRoot"
