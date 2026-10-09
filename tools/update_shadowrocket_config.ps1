[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputPath,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$baseUrl = 'https://raw.githubusercontent.com/keixhuiq/domains-and-ips/main/shadowrocket'
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $InputPath).Path)
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }

function Get-SectionBounds {
    param([string]$Content, [string]$Name)
    $startToken = "[$Name]$newline"
    $start = $Content.IndexOf($startToken, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Missing [$Name] section." }
    $next = $Content.IndexOf("$newline[", $start + $startToken.Length, [StringComparison]::Ordinal)
    if ($next -lt 0) { $next = $Content.Length }
    [pscustomobject]@{ Start = $start; End = $next }
}

function Add-RuleSetReference {
    param(
        [Collections.Generic.List[string]]$Lines,
        [Parameter(Mandatory)][string]$Stem,
        [Parameter(Mandatory)][string]$Policy
    )
    $suffix = if ($Stem.EndsWith('-domain') -and $Policy -notin @('Direct', 'Block')) { ',force-remote-dns' } else { '' }
    $Lines.Add("RULE-SET,$baseUrl/$Stem.list,$Policy$suffix")
}

# Rebuild only the Proxy Group section; node and subscription sections remain untouched.
$proxyBounds = Get-SectionBounds -Content $text -Name 'Proxy Group'
$proxyText = $text.Substring($proxyBounds.Start, $proxyBounds.End - $proxyBounds.Start)
$proxyLines = @($proxyText -split '\r?\n')
$groupLines = [ordered]@{}
foreach ($line in $proxyLines) {
    if ($line -match '^(?<name>[^#=]+)\s*=') { $groupLines[$Matches.name.Trim()] = $line }
}
foreach ($name in @('Proxies','Claude','Google','Scholar','BOOKWALKERJP','BOOKWALKERTW','Abema','🎯Direct','✈️Final')) {
    if (-not $groupLines.Contains($name)) { throw "Expected source proxy group '$name' was not found." }
}

$normalizedGroups = [ordered]@{}
foreach ($lineObject in $proxyLines | Select-Object -Skip 1) {
    $line = [string]$lineObject
    if ($line -notmatch '^(?<name>[^#=]+)\s*=') { continue }
    $name = $Matches.name.Trim()
    if ($name -eq 'BOOKWALKERTW') { continue }
    if ($name -eq 'BOOKWALKERJP') {
        $name = 'BookWalker'
        $line = $line -replace '^BOOKWALKERJP\s*=', 'BookWalker ='
    }
    elseif ($name -eq 'Abema') {
        $name = 'ABEMA'
        $line = $line -replace '^Abema\s*=', 'ABEMA ='
    }
    elseif ($name -eq '🎯Direct') {
        $name = 'Direct'
        $line = $line -replace '^🎯Direct\s*=', 'Direct ='
    }

    $line = $line -replace '(?i)(?<=,)🎯Direct(?=,|$)', 'Direct'
    $line = $line -replace '(?i)(policy-select-name=)🎯Direct(?=,|$)', '${1}Direct'
    $normalizedGroups[$name] = $line
}

$normalizedGroups['SpecialTools'] = 'SpecialTools = select,Proxies,Direct,REJECT,policy-select-name=Proxies'
$normalizedGroups['Amazon'] = 'Amazon = select,Proxies,Direct,policy-select-name=Proxies'
$normalizedGroups['NVIDIA'] = 'NVIDIA = select,Proxies,Direct,policy-select-name=Proxies'
$normalizedGroups['Block'] = 'Block = select,REJECT,REJECT-NO-DROP,Direct,policy-select-name=REJECT'

$productionGroupOrder = @(
    'SpecialTools','Claude','OpenAI','LINE','X','TikTok','Netflix','Crunchyroll','ABEMA','U-NEXT','Spotify','Pixiv',
    'BookWalker','DisneyPlus','HBO','Bahamut','MyTVSuper','YouTube','Steam','Epic','Xbox','PlayStation','Google',
    'Amazon','NVIDIA','Scholar','Crypto','Telegram','Meta','Bilibili','Microsoft','Apple','Proxies','Direct','Block'
)
$newProxyLines = [Collections.Generic.List[string]]::new()
$newProxyLines.Add('[Proxy Group]')
foreach ($name in $productionGroupOrder) {
    if (-not $normalizedGroups.Contains($name)) { throw "Unable to build production policy group '$name'." }
    $newProxyLines.Add($normalizedGroups[$name])
}
$newProxyLines.Add($normalizedGroups['✈️Final'])

$newProxyText = (($newProxyLines -join $newline).TrimEnd("`r", "`n"))
$text = $text.Substring(0, $proxyBounds.Start) + $newProxyText + $text.Substring($proxyBounds.End)

# Replace remote references in the Rule section; retain local iOS-only inline rules.
$ruleBounds = Get-SectionBounds -Content $text -Name 'Rule'
$ruleText = $text.Substring($ruleBounds.Start, $ruleBounds.End - $ruleBounds.Start)
$ruleLines = @($ruleText -split '\r?\n')
$updated = [Collections.Generic.List[string]]::new()
$inserted = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

$headingMap = [ordered]@{
    '# ===== Claude =====' = @('Claude-domain|Claude')
    '# ===== OpenAI =====' = @('OpenAI-domain|OpenAI')
    '# ===== LINE =====' = @('LINE-domain|LINE','LINE-ip|LINE')
    '# ===== X =====' = @('X-domain|X','X-ip|X')
    '# ===== TikTok =====' = @('TikTok-domain|TikTok')
    '# ===== Netflix =====' = @('Netflix-domain|Netflix','Netflix-ip|Netflix')
    '# ===== Crunchyroll =====' = @('Crunchyroll-domain|Crunchyroll')
    '# ===== Abema =====' = @('ABEMA-domain|ABEMA')
    '# ===== U-NEXT =====' = @('U-NEXT-domain|U-NEXT')
    '# ===== Spotify =====' = @('Spotify-domain|Spotify','Spotify-ip|Spotify')
    '# ===== Pixiv =====' = @('Pixiv-domain|Pixiv')
    '# ===== Bilibili =====' = @('Bilibili-domain|Bilibili','Bilibili-ip|Bilibili')
    '# ===== Disney Plus =====' = @('DisneyPlus-domain|DisneyPlus')
    '# ===== HBO =====' = @('HBO-domain|HBO')
    '# ===== Bahamut =====' = @('Bahamut-domain|Bahamut')
    '# ===== MyTVSuper =====' = @('MyTVSuper-domain|MyTVSuper')
    '# ===== YouTube =====' = @('YouTube-domain|YouTube','YouTube-ip|YouTube')
    '# ===== Steam =====' = @('Steam-domain|Steam')
    '# ===== Epic =====' = @('Epic-domain|Epic')
    '# ===== Xbox =====' = @('Xbox-domain|Xbox')
    '# ===== PlayStation =====' = @('PlayStation-domain|PlayStation')
    '# ===== Google =====' = @('Google-domain|Google','Google-ip|Google')
    '# ===== Microsoft =====' = @('Microsoft-domain|Microsoft')
    '# ===== Apple =====' = @('Apple-domain|Apple','Apple-ip|Apple')
    '# ===== Scholar =====' = @('Scholar-domain|Scholar')
    '# ===== Crypto =====' = @('Crypto-domain|Crypto')
    '# ===== Telegram =====' = @('Telegram-domain|Telegram','Telegram-ip|Telegram')
    '# ===== Meta =====' = @('Meta-domain|Meta','Meta-ip|Meta')
    '# ===== 自维护的通用代理规则集 =====' = @('CustomProxy-domain|Proxies','CustomProxy-ip|Proxies')
    '# ===== 国内直连（规则集）=====' = @('China-domain|Direct','China-ip|Direct')
}

foreach ($lineObject in $ruleLines) {
    $line = [string]$lineObject
    if ($line -match '^(RULE-SET|DOMAIN-SET),') { continue }
    if ($line -in @('# sing-box logical exclusion: google.com except storage.cloud.google.com','# Preserve the sing-box logical exclusion before Google-domain.list')) { continue }
    if ($line -eq 'DOMAIN-SUFFIX,storage.cloud.google.com,✈️Final,force-remote-dns') { continue }

    if ($line -eq '# ===== BOOKWALKER JP =====') {
        $updated.Add('# ===== BookWalker =====')
        Add-RuleSetReference -Lines $updated -Stem 'BookWalker-domain' -Policy 'BookWalker'
        [void]$inserted.Add('BookWalker-domain')
        continue
    }
    if ($line -eq '# ===== BOOKWALKER TW =====') { continue }

    if ($line -eq '# ===== Scholar =====') {
        $updated.Add('# ===== Amazon =====')
        Add-RuleSetReference -Lines $updated -Stem 'Amazon-domain' -Policy 'Amazon'
        [void]$inserted.Add('Amazon-domain')
        $updated.Add('')
        $updated.Add('# ===== NVIDIA =====')
        Add-RuleSetReference -Lines $updated -Stem 'NVIDIA-domain' -Policy 'NVIDIA'
        [void]$inserted.Add('NVIDIA-domain')
        $updated.Add('')
    }

    if ($line -eq '# ===== Google =====') {
        $updated.Add($line)
        $updated.Add('# Preserve the sing-box logical exclusion before Google-domain.list')
        $updated.Add('DOMAIN-SUFFIX,storage.cloud.google.com,✈️Final,force-remote-dns')
        foreach ($reference in $headingMap[$line]) {
            $fields = $reference -split '\|', 2
            Add-RuleSetReference -Lines $updated -Stem $fields[0] -Policy $fields[1]
            [void]$inserted.Add($fields[0])
        }
        continue
    }

    if ($headingMap.Contains($line)) {
        $updated.Add($(if ($line -eq '# ===== Abema =====') { '# ===== ABEMA =====' } else { $line }))
        foreach ($reference in $headingMap[$line]) {
            $fields = $reference -split '\|', 2
            Add-RuleSetReference -Lines $updated -Stem $fields[0] -Policy $fields[1]
            [void]$inserted.Add($fields[0])
        }
        continue
    }

    $updated.Add($line)
    if ($line -eq '#AND,((PROTOCOL,UDP),(DST-PORT,443)),REJECT-NO-DROP') {
        foreach ($stem in @('block-port','block-domain','block-ip')) {
            Add-RuleSetReference -Lines $updated -Stem $stem -Policy 'Block'
            [void]$inserted.Add($stem)
        }
    }
    elseif ($line -eq '# ===== 个性化规则 本地直连  常规 =====') {
        foreach ($stem in @('direct-domain','direct-ip')) {
            Add-RuleSetReference -Lines $updated -Stem $stem -Policy 'Direct'
            [void]$inserted.Add($stem)
        }
    }
    elseif ($line -eq '# ===== 校园网内网直连 =====') {
        Add-RuleSetReference -Lines $updated -Stem 'Private-ip' -Policy 'Direct'
        [void]$inserted.Add('Private-ip')
    }
}

$expectedStems = @(
    'ABEMA-domain','Amazon-domain','Apple-domain','Apple-ip','Bahamut-domain','Bilibili-domain','Bilibili-ip',
    'block-domain','block-ip','block-port','BookWalker-domain','China-domain','China-ip','Claude-domain',
    'Crunchyroll-domain','Crypto-domain','CustomProxy-domain','CustomProxy-ip','direct-domain','direct-ip',
    'DisneyPlus-domain','Epic-domain','Google-domain','Google-ip','HBO-domain','LINE-domain','LINE-ip',
    'Meta-domain','Meta-ip','Microsoft-domain','MyTVSuper-domain','Netflix-domain','Netflix-ip','NVIDIA-domain',
    'OpenAI-domain','Pixiv-domain','PlayStation-domain','Private-ip','Scholar-domain','Spotify-domain','Spotify-ip',
    'Steam-domain','Telegram-domain','Telegram-ip','TikTok-domain','U-NEXT-domain','X-domain','X-ip','Xbox-domain',
    'YouTube-domain','YouTube-ip'
)
$missingStems = @($expectedStems | Where-Object { -not $inserted.Contains($_) })
if ($inserted.Count -ne $expectedStems.Count -or $missingStems.Count -gt 0) {
    throw "Remote reference coverage mismatch. Inserted $($inserted.Count), expected $($expectedStems.Count); missing: $($missingStems -join ', ')."
}

$policyAliases = @{
    'proxies'='Proxies'; 'direct'='Direct'; 'reject'='Block'; '🎯direct'='Direct'; '✈️final'='✈️Final';
    'abema'='ABEMA'; 'bookwalkerjp'='BookWalker'; 'bookwalkertw'='BookWalker'
}
for ($i = 0; $i -lt $updated.Count; $i++) {
    $line = $updated[$i]
    if ($line.StartsWith('#') -or $line -eq '' -or $line -match '^(RULE-SET|DOMAIN-SET),') { continue }
    $parts = $line -split ','
    if ($parts.Count -lt 2) { continue }
    $policyIndex = if ($parts[0] -eq 'FINAL') { 1 } else { 2 }
    if ($parts.Count -le $policyIndex) { continue }
    $key = $parts[$policyIndex].ToLowerInvariant()
    if ($policyAliases.ContainsKey($key)) {
        $parts[$policyIndex] = $policyAliases[$key]
        $updated[$i] = $parts -join ','
    }
}

$newRuleText = (($updated -join $newline).TrimEnd("`r", "`n"))
$outputText = $text.Substring(0, $ruleBounds.Start) + $newRuleText + $text.Substring($ruleBounds.End)
$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }
[IO.File]::WriteAllText($OutputPath, $outputText, $utf8NoBom)
Write-Host "Wrote production-aligned Shadowrocket config copy to $OutputPath"
