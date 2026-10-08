[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputPath,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$baseUrl = 'https://raw.githubusercontent.com/keixhuiq/domains-and-ips/main/shadowrocket'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $InputPath).Path)
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }

$ruleStart = $text.IndexOf('[Rule]' + $newline, [StringComparison]::Ordinal)
if ($ruleStart -lt 0) { throw 'The input config has no [Rule] section.' }
$nextSection = $text.IndexOf($newline + '[', $ruleStart + 1, [StringComparison]::Ordinal)
if ($nextSection -lt 0) { $nextSection = $text.Length }

$prefix = $text.Substring(0, $ruleStart)
$ruleText = $text.Substring($ruleStart, $nextSection - $ruleStart)
$suffix = $text.Substring($nextSection)
$lines = [System.Collections.Generic.List[string]]::new()
foreach ($line in ($ruleText -split '\r?\n')) { $lines.Add($line) }

$serviceMap = @{
    'Claude' = @('Claude', 'Claude')
    'OpenAI' = @('OpenAI', 'OpenAI')
    'Line' = @('LINE', 'LINE')
    'Twitter' = @('X', 'X')
    'TikTok' = @('TikTok', 'TikTok')
    'Netflix' = @('Netflix', 'Netflix')
    'Crunchyroll' = @('Crunchyroll', 'Crunchyroll')
    'Abema' = @('ABEMA', 'Abema')
    'UNEXT' = @('UNEXT', 'U-NEXT')
    'Spotify' = @('Spotify', 'Spotify')
    'Pixiv' = @('Pixiv', 'Pixiv')
    'bookwalker.jp' = @('BookWalkerJP', 'BOOKWALKERJP')
    'bookwalker.tw' = @('BookWalkerTW', 'BOOKWALKERTW')
    'BiliBili' = @('Bilibili', 'Bilibili')
    'Disney' = @('DisneyPlus', 'DisneyPlus')
    'HBO' = @('HBO', 'HBO')
    'Bahamut' = @('Bahamut', 'Bahamut')
    'myTVSUPER' = @('MyTVSuper', 'MyTVSuper')
    'YouTube' = @('YouTube', 'YouTube')
    'Steam' = @('Steam', 'Steam')
    'Epic' = @('Epic', 'Epic')
    'Xbox' = @('Xbox', 'Xbox')
    'PlayStation' = @('PlayStation', 'PlayStation')
    'Google' = @('Google', 'Google')
    'Microsoft' = @('Microsoft', 'Microsoft')
    'Scholar' = @('Scholar', 'Scholar')
    'Crypto' = @('Crypto', 'Crypto')
    'Telegram' = @('Telegram', 'Telegram')
    'CustomProxy' = @('CustomProxy', 'Proxies')
}

$updated = [System.Collections.Generic.List[string]]::new()
$metaWritten = $false
$blockWritten = $false
$directWritten = $false
$privateWritten = $false
$googleExceptionWritten = $false

foreach ($line in $lines) {
    if ($line -match '^(RULE-SET|DOMAIN-SET),(?<url>https://raw\.githubusercontent\.com/[^,]+),(?<policy>[^,]+)(?<options>,.*)?$') {
        $url = $Matches.url
        $options = if ($Matches.ContainsKey('options')) { $Matches['options'] } else { '' }

        if ($url -match '/(?:Facebook|Instagram|Whatsapp)/') {
            if (-not $metaWritten) {
                $updated.Add("RULE-SET,$baseUrl/Meta.list,Meta,force-remote-dns")
                $metaWritten = $true
            }
            continue
        }

        if ($url -match '/Apple/Apple_Domain\.list$') {
            $updated.Add("DOMAIN-SET,$baseUrl/Apple_Domain.list,Apple")
            continue
        }
        if ($url -match '/Apple/Apple\.list$') {
            $updated.Add("RULE-SET,$baseUrl/Apple.list,Apple")
            continue
        }
        if ($url -match '/ChinaMax/ChinaMax_Domain\.list$') {
            $updated.Add("DOMAIN-SET,$baseUrl/China_Domain.list,🎯Direct")
            continue
        }
        if ($url -match '/ChinaMax/ChinaMax\.list$') {
            $updated.Add("RULE-SET,$baseUrl/China.list,🎯Direct")
            continue
        }

        $matched = $false
        foreach ($key in $serviceMap.Keys) {
            if ($url -match "/$([regex]::Escape($key))/(?:DOMAIN|$([regex]::Escape($key)))\.list$") {
                $fileName = $serviceMap[$key][0]
                $policy = $serviceMap[$key][1]
                if ($fileName -eq 'CustomProxy') {
                    $updated.Add("DOMAIN-SET,$baseUrl/CustomProxy_Domain.list,$policy,force-remote-dns")
                }
                $tail = if ([string]::IsNullOrEmpty($options)) { '' } else { $options }
                $updated.Add("RULE-SET,$baseUrl/$fileName.list,$policy$tail")
                $matched = $true
                break
            }
        }
        if ($matched) { continue }
        throw "Unmapped remote rule reference: $line"
    }

    $updated.Add($line)

    if (-not $blockWritten -and $line -eq '#AND,((PROTOCOL,UDP),(DST-PORT,443)),REJECT-NO-DROP') {
        $updated.Add("RULE-SET,$baseUrl/Block.list,REJECT")
        $blockWritten = $true
    }
    elseif (-not $directWritten -and $line -eq '# ===== 个性化规则 本地直连  常规 =====') {
        $updated.Add("RULE-SET,$baseUrl/Direct.list,🎯Direct")
        $directWritten = $true
    }
    elseif (-not $privateWritten -and $line -eq '# ===== 校园网内网直连 =====') {
        $updated.Add("RULE-SET,$baseUrl/Private.list,🎯Direct")
        $privateWritten = $true
    }
    elseif (-not $googleExceptionWritten -and $line -eq '# ===== Google =====') {
        $updated.Add('# sing-box logical exclusion: google.com except storage.cloud.google.com')
        $updated.Add('DOMAIN-SUFFIX,storage.cloud.google.com,✈️Final,force-remote-dns')
        $googleExceptionWritten = $true
    }
}

if (-not ($blockWritten -and $directWritten -and $privateWritten -and $googleExceptionWritten -and $metaWritten)) {
    throw 'One or more required Shadowrocket insertions were not applied.'
}

$outputText = $prefix + (($updated -join $newline).TrimEnd("`r", "`n") + $newline) + $suffix
$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }
[IO.File]::WriteAllText($OutputPath, $outputText, $utf8NoBom)
Write-Host "Wrote updated config copy to $OutputPath"
