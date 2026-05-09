import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

const old = (file) => `https://raw.githubusercontent.com/whxhuiq-creator/proxy-rules/main/Surge/${file}`;
const b7 = (path) => `https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/${path}`;
const qh = (path) => `https://raw.githubusercontent.com/QuixoticHeart/rule-set/ruleset/surge/${path}`;

const directSources = [
  { target: 'Surge/ChinaDirect.list', url: b7('ChinaMax/ChinaMax_All.list') },
  { target: 'Surge/Apple.list', url: b7('Apple/Apple_All.list') },
  { target: 'Surge/Google.list', url: b7('Google/Google.list') },
  { target: 'Surge/ChinaIPv4.list', url: b7('ChinaIPsBGP/ChinaIPsBGP.list') },
  { target: 'Surge/ChinaIPv6.list', url: 'https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/ChinaIpV6.list' },
];

const mergedSources = [
  { name: 'Abema', target: 'Surge/Abema.list', sources: ['old manual Abema', 'blackmatrix7 Abema/AbemaTV', 'QuixoticHeart abema'], urls: [old('Abema.list'), b7('Abema/Abema.list'), b7('AbemaTV/AbemaTV.list'), qh('abema.list')] },
  { name: 'UNEXT', target: 'Surge/UNEXT.list', sources: ['old manual UNEXT', 'HotKids U-NEXT'], urls: [old('UNEXT.list'), 'https://raw.githubusercontent.com/HotKids/Rules/master/Surge/RULE-SET/U-NEXT.list'] },
  { name: 'X', target: 'Surge/X.list', sources: ['old manual X', 'blackmatrix7 Twitter', 'ACL4SSR Twitter'], urls: [old('X.list'), b7('Twitter/Twitter.list'), 'https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/Ruleset/Twitter.list'] },
  { name: 'TikTok', target: 'Surge/TikTok.list', sources: ['old manual TikTok', 'blackmatrix7 TikTok', 'QuixoticHeart tiktok'], urls: [old('TikTok.list'), b7('TikTok/TikTok.list'), qh('tiktok.list')] },
  { name: 'OpenAI', target: 'Surge/OpenAI.list', sources: ['old manual OpenAI', 'blackmatrix7 OpenAI', 'geekdada openai'], urls: [old('OpenAI.list'), b7('OpenAI/OpenAI.list'), 'https://raw.githubusercontent.com/geekdada/surge-list/master/openai.list'] },
  { name: 'Claude', target: 'Surge/Claude.list', sources: ['old manual Claude', 'blackmatrix7 Claude/Anthropic', 'HotKids Anthropic'], urls: [old('Claude.list'), b7('Claude/Claude.list'), b7('Anthropic/Anthropic.list'), 'https://raw.githubusercontent.com/HotKids/Rules/master/Surge/RULE-SET/Anthropic.list'] },
  { name: 'Bahamut', target: 'Surge/Bahamut.list', sources: ['old manual Bahamut', 'blackmatrix7 Bahamut', 'QuixoticHeart bahamut'], urls: [old('Bahamut.list'), b7('Bahamut/Bahamut.list'), qh('bahamut.list')] },
  { name: 'Bilibili', target: 'Surge/Bilibili.list', sources: ['old manual Bilibili', 'blackmatrix7 BiliBili', 'QuixoticHeart bilibili'], urls: [old('Bilibili.list'), b7('BiliBili/BiliBili.list'), qh('bilibili.list')] },
  { name: 'Crypto', target: 'Surge/Crypto.list', sources: ['old manual Crypto', 'blackmatrix7 Cryptocurrency', 'QuixoticHeart crypto'], urls: [old('Crypto.list'), b7('Cryptocurrency/Cryptocurrency.list'), qh('crypto.list')] },
  { name: 'CustomProxy', target: 'Surge/CustomProxy.list', sources: ['old manual CustomProxy', 'blackmatrix7 ProxyLite', 'ACL4SSR ProxyLite'], urls: [old('CustomProxy.list'), b7('ProxyLite/ProxyLite.list'), 'https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/ProxyLite.list'] },
  { name: 'DisneyPlus', target: 'Surge/DisneyPlus.list', sources: ['old manual DisneyPlus', 'blackmatrix7 Disney', 'QuixoticHeart disney'], urls: [old('DisneyPlus.list'), b7('Disney/Disney.list'), qh('disney.list')] },
  { name: 'Epic', target: 'Surge/Epic.list', sources: ['old manual Epic', 'blackmatrix7 Epic'], urls: [old('Epic.list'), b7('Epic/Epic.list')] },
  { name: 'HBO', target: 'Surge/HBO.list', sources: ['old manual HBO', 'blackmatrix7 HBO/HBOUSA', 'QuixoticHeart hbo'], urls: [old('HBO.list'), b7('HBO/HBO.list'), b7('HBOUSA/HBOUSA.list'), qh('hbo.list')] },
  { name: 'LINE', target: 'Surge/LINE.list', sources: ['old manual LINE', 'blackmatrix7 Line'], urls: [old('LINE.list'), b7('Line/Line.list')] },
  { name: 'Microsoft', target: 'Surge/Microsoft.list', sources: ['old manual Microsoft', 'blackmatrix7 Microsoft', 'QuixoticHeart microsoft'], urls: [old('Microsoft.list'), b7('Microsoft/Microsoft.list'), qh('microsoft.list')] },
  { name: 'MyTVSuper', target: 'Surge/MyTVSuper.list', sources: ['old manual MyTVSuper', 'blackmatrix7 myTVSUPER', 'QuixoticHeart mytvsuper'], urls: [old('MyTVSuper.list'), b7('myTVSUPER/myTVSUPER.list'), qh('mytvsuper.list')] },
  { name: 'Netflix', target: 'Surge/Netflix.list', sources: ['old manual Netflix', 'blackmatrix7 Netflix', 'QuixoticHeart netflix'], urls: [old('Netflix.list'), b7('Netflix/Netflix.list'), qh('netflix.list')] },
  { name: 'PlayStation', target: 'Surge/PlayStation.list', sources: ['old manual PlayStation', 'blackmatrix7 PlayStation'], urls: [old('PlayStation.list'), b7('PlayStation/PlayStation.list')] },
  { name: 'Scholar', target: 'Surge/Scholar.list', sources: ['old manual Scholar', 'blackmatrix7 Scholar'], urls: [old('Scholar.list'), b7('Scholar/Scholar.list')] },
  { name: 'Steam', target: 'Surge/Steam.list', sources: ['old manual Steam', 'blackmatrix7 Steam'], urls: [old('Steam.list'), b7('Steam/Steam.list')] },
  { name: 'Telegram', target: 'Surge/Telegram.list', sources: ['old manual Telegram', 'blackmatrix7 Telegram', 'ACL4SSR Telegram'], urls: [old('Telegram.list'), b7('Telegram/Telegram.list'), 'https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/Telegram.list'] },
  { name: 'Xbox', target: 'Surge/Xbox.list', sources: ['old manual Xbox', 'blackmatrix7 Xbox'], urls: [old('Xbox.list'), b7('Xbox/Xbox.list')] },
  { name: 'YouTube', target: 'Surge/YouTube.list', sources: ['old manual YouTube', 'blackmatrix7 YouTube', 'QuixoticHeart youtube'], urls: [old('YouTube.list'), b7('YouTube/YouTube.list'), qh('youtube.list')] },
];

const ipRuleTypes = new Set(['IP-CIDR', 'IP-CIDR6', 'IP-ASN', 'GEOIP']);
const supportedFlags = new Set(['no-resolve', 'extended-matching', 'force-remote-dns', 'no-alert']);

const claudeOpenAISharedRules = [
  'DOMAIN-SUFFIX,stripe.com',
  'DOMAIN-SUFFIX,sentry.io',
  'DOMAIN-SUFFIX,intercom.io',
  'DOMAIN-SUFFIX,intercomcdn.com',
  'DOMAIN-SUFFIX,statsigapi.net',
  'DOMAIN-SUFFIX,featuregates.org',
  'DOMAIN-SUFFIX,launchdarkly.com',
  'DOMAIN-SUFFIX,segment.io',
];

const sharedRuleMarkersByTarget = {
  'Surge/Claude.list': new Map(claudeOpenAISharedRules.map((rule) => [rule, '# SHARED: OpenAI'])),
  'Surge/OpenAI.list': new Map(claudeOpenAISharedRules.map((rule) => [rule, '# SHARED: Claude'])),
};

const replacementsByTarget = {
  'Surge/Claude.list': new Map([
    ['DOMAIN-SUFFIX,anthropic.statuspage.io', 'DOMAIN,anthropic.statuspage.io'],
  ]),
  'Surge/OpenAI.list': new Map([
    ['DOMAIN-SUFFIX,openaiapi-site.azureedge.net', 'DOMAIN,openaiapi-site.azureedge.net'],
    ['DOMAIN-SUFFIX,openaicom.imgix.net', 'DOMAIN,openaicom.imgix.net'],
    ['DOMAIN-SUFFIX,openaicomproductionae4b.blob.core.windows.net', 'DOMAIN,openaicomproductionae4b.blob.core.windows.net'],
    ['DOMAIN-SUFFIX,openaicom-api-bdcpf8c6d2e9atf6.z01.azurefd.net', 'DOMAIN,openaicom-api-bdcpf8c6d2e9atf6.z01.azurefd.net'],
    ['DOMAIN-SUFFIX,production-openaicom-storage.azureedge.net', 'DOMAIN,production-openaicom-storage.azureedge.net'],
    ['DOMAIN-SUFFIX,openai.com.cdn.cloudflare.net', 'DOMAIN,openai.com.cdn.cloudflare.net'],
    ['DOMAIN-SUFFIX,chat.openai.com.cdn.cloudflare.net', 'DOMAIN,chat.openai.com.cdn.cloudflare.net'],
    ['DOMAIN-SUFFIX,ios.chat.openai.com.cdn.cloudflare.net', 'DOMAIN,ios.chat.openai.com.cdn.cloudflare.net'],
    ['DOMAIN-SUFFIX,api.statsig.com', 'DOMAIN,api.statsig.com'],
    ['DOMAIN-SUFFIX,client-api.arkoselabs.com', 'DOMAIN,client-api.arkoselabs.com'],
  ]),
  'Surge/TikTok.list': new Map([
    ['DOMAIN-KEYWORD,tiktok', 'DOMAIN-SUFFIX,tiktok.com'],
  ]),
};

const removalsByTarget = {
  'Surge/Claude.list': new Set([
    'DOMAIN,api.anthropic.com',
    'DOMAIN-KEYWORD,datadog',
    'DOMAIN-KEYWORD,sift',
  ]),
  'Surge/OpenAI.list': new Set([
    'DOMAIN-KEYWORD,openai',
    'DOMAIN-KEYWORD,chatgpt',
    'DOMAIN-SUFFIX,algolia.net',
    'DOMAIN-SUFFIX,chatgpt.livekit.cloud',
    'DOMAIN-SUFFIX,events.statsigapi.net',
    'DOMAIN-SUFFIX,host.livekit.cloud',
    'DOMAIN-SUFFIX,identrust.com',
    'DOMAIN-SUFFIX,observeit.net',
    'DOMAIN-SUFFIX,turn.livekit.cloud',
  ]),
  'Surge/TikTok.list': new Set([
    'IP-CIDR,34.102.0.0/16,no-resolve',
    'IP-CIDR,130.211.0.0/16,no-resolve',
    'DOMAIN-KEYWORD,adjust',
    'DOMAIN-KEYWORD,musical.ly',
    'DOMAIN-SUFFIX,adjust.com',
    'DOMAIN-SUFFIX,appsflyer.com',
    'DOMAIN-SUFFIX,p16-tiktokcdn-com.akamaized.net',
    'PROCESS-NAME,com.zhiliaoapp.musically',
  ]),
  'Surge/X.list': new Set([
    'DOMAIN-KEYWORD,twitter',
  ]),
};

const additionsByTarget = {
  'Surge/LINE.list': ['IP-ASN,38631,no-resolve'],
  'Surge/OpenAI.list': ['DOMAIN-SUFFIX,statsigapi.net'],
  'Surge/X.list': ['DOMAIN-SUFFIX,x.ai', 'IP-ASN,13414,no-resolve'],
};

async function fetchRule(url) {
  const response = await fetch(url, {
    headers: {
      'user-agent': 'proxy-rules-clean-updater',
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}: ${response.status} ${response.statusText}`);
  }

  const text = await response.text();
  return `${text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').trim()}\n`;
}

function normalizeRuleLine(line) {
  const trimmed = line.trim();

  if (
    !trimmed ||
    trimmed.startsWith('#') ||
    trimmed.startsWith('//') ||
    trimmed === 'payload:' ||
    trimmed === 'rules:'
  ) {
    return null;
  }

  const yamlItem = trimmed.match(/^[-+]\s*['"]?(.+?)['"]?\s*$/);
  const raw = yamlItem ? yamlItem[1].trim() : trimmed;

  if (!raw || raw.startsWith('#') || raw.startsWith('//')) {
    return null;
  }

  const parts = raw.split(',').map((part) => part.trim()).filter(Boolean);
  if (parts.length < 2) {
    return null;
  }

  const type = parts[0].toUpperCase();
  if (!/^[A-Z0-9-]+$/.test(type)) {
    return null;
  }

  if (ipRuleTypes.has(type)) {
    const flags = parts.slice(2).filter((part) => supportedFlags.has(part.toLowerCase()));
    return [type, parts[1], ...flags].join(',');
  }

  return [type, parts[1]].join(',');
}

function forceNoResolveForIpRules(rules) {
  return rules.map((rule) => {
    const parts = rule.split(',');
    const type = parts[0];
    if (!ipRuleTypes.has(type) || type === 'GEOIP') {
      return rule;
    }

    const flags = new Set(parts.slice(2));
    flags.add('no-resolve');
    return [type, parts[1], ...flags].join(',');
  });
}

function uniqueRules(rules) {
  const seen = new Set();
  const result = [];

  for (const rule of rules) {
    if (!seen.has(rule)) {
      seen.add(rule);
      result.push(rule);
    }
  }

  return result;
}

function cleanupRules(target, rules) {
  const replacements = replacementsByTarget[target] ?? new Map();
  const removals = removalsByTarget[target] ?? new Set();
  let cleaned = rules.map((rule) => replacements.get(rule) ?? rule).filter((rule) => !removals.has(rule));

  if (target === 'Surge/LINE.list' || target === 'Surge/X.list') {
    cleaned = forceNoResolveForIpRules(cleaned);
  }

  cleaned = uniqueRules([...cleaned, ...(additionsByTarget[target] ?? [])]);
  return cleaned;
}

function markSharedRules(target, rules) {
  const markers = sharedRuleMarkersByTarget[target] ?? new Map();
  const result = [];

  for (const rule of rules) {
    const marker = markers.get(rule);
    if (marker) {
      result.push(marker);
    }
    result.push(rule);
  }

  return result;
}

function buildMergedContent(ruleSet, rules) {
  return [
    `# NAME: ${ruleSet.name}`,
    '# FORMAT: Surge rule-set',
    `# SOURCES: ${ruleSet.sources.join('; ')}`,
    `# TOTAL: ${rules.length}`,
    ...markSharedRules(ruleSet.target, rules),
    '',
  ].join('\n');
}

async function writeRule(target, content) {
  await mkdir(dirname(target), { recursive: true });
  await writeFile(target, content, 'utf8');
}

for (const source of directSources) {
  const content = await fetchRule(source.url);
  await writeRule(source.target, content);
  console.log(`Updated ${source.target} from ${source.url}`);
}

for (const ruleSet of mergedSources) {
  const rules = new Map();

  for (const url of ruleSet.urls) {
    const content = await fetchRule(url);

    for (const line of content.split('\n')) {
      const rule = normalizeRuleLine(line);
      if (rule && !rules.has(rule)) {
        rules.set(rule, true);
      }
    }
  }

  const cleanedRules = cleanupRules(ruleSet.target, [...rules.keys()]);
  await writeRule(ruleSet.target, buildMergedContent(ruleSet, cleanedRules));
  console.log(`Updated ${ruleSet.target} from ${ruleSet.urls.length} sources`);
}
