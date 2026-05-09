import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

const directSources = [
  {
    target: 'Surge/ChinaDirect.list',
    url: 'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/ChinaMax/ChinaMax_All.list',
  },
  {
    target: 'Surge/Apple.list',
    url: 'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/Apple/Apple_All.list',
  },
  {
    target: 'Surge/Google.list',
    url: 'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/Google/Google.list',
  },
  {
    target: 'Surge/ChinaIPv4.list',
    url: 'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/ChinaIPsBGP/ChinaIPsBGP.list',
  },
  {
    target: 'Surge/ChinaIPv6.list',
    url: 'https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/ChinaIpV6.list',
  },
];

const mergedSources = [
  {
    name: 'Abema',
    target: 'Surge/Abema.list',
    sources: [
      'whxhuiq-creator/proxy-rules Surge/Abema',
      'blackmatrix7/ios_rule_script Abema',
      'blackmatrix7/ios_rule_script AbemaTV',
      'QuixoticHeart/rule-set abema',
    ],
    urls: [
      'https://raw.githubusercontent.com/whxhuiq-creator/proxy-rules/main/Surge/Abema.list',
      'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/Abema/Abema.list',
      'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/AbemaTV/AbemaTV.list',
      'https://raw.githubusercontent.com/QuixoticHeart/rule-set/ruleset/surge/abema.list',
    ],
  },
  {
    name: 'UNEXT',
    target: 'Surge/UNEXT.list',
    sources: [
      'whxhuiq-creator/proxy-rules Surge/UNEXT',
      'HotKids/Rules U-NEXT',
    ],
    urls: [
      'https://raw.githubusercontent.com/whxhuiq-creator/proxy-rules/main/Surge/UNEXT.list',
      'https://raw.githubusercontent.com/HotKids/Rules/master/Surge/RULE-SET/U-NEXT.list',
    ],
  },
  {
    name: 'X',
    target: 'Surge/X.list',
    sources: [
      'whxhuiq-creator/proxy-rules Surge/X',
      'blackmatrix7/ios_rule_script Twitter',
      'ACL4SSR/ACL4SSR Twitter',
    ],
    urls: [
      'https://raw.githubusercontent.com/whxhuiq-creator/proxy-rules/main/Surge/X.list',
      'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/Twitter/Twitter.list',
      'https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/Ruleset/Twitter.list',
    ],
  },
  {
    name: 'TikTok',
    target: 'Surge/TikTok.list',
    sources: [
      'whxhuiq-creator/proxy-rules Surge/TikTok',
      'blackmatrix7/ios_rule_script TikTok',
      'QuixoticHeart/rule-set tiktok',
    ],
    urls: [
      'https://raw.githubusercontent.com/whxhuiq-creator/proxy-rules/main/Surge/TikTok.list',
      'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/TikTok/TikTok.list',
      'https://raw.githubusercontent.com/QuixoticHeart/rule-set/ruleset/surge/tiktok.list',
    ],
  },
  {
    name: 'OpenAI',
    target: 'Surge/OpenAI.list',
    sources: [
      'whxhuiq-creator/proxy-rules Surge/OpenAI',
      'blackmatrix7/ios_rule_script OpenAI',
      'geekdada/surge-list openai',
    ],
    urls: [
      'https://raw.githubusercontent.com/whxhuiq-creator/proxy-rules/main/Surge/OpenAI.list',
      'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/OpenAI/OpenAI.list',
      'https://raw.githubusercontent.com/geekdada/surge-list/master/openai.list',
    ],
  },
  {
    name: 'Claude',
    target: 'Surge/Claude.list',
    sources: [
      'whxhuiq-creator/proxy-rules Surge/Claude',
      'blackmatrix7/ios_rule_script Claude',
      'blackmatrix7/ios_rule_script Anthropic',
      'HotKids/Rules Anthropic',
    ],
    urls: [
      'https://raw.githubusercontent.com/whxhuiq-creator/proxy-rules/main/Surge/Claude.list',
      'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/Claude/Claude.list',
      'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/Anthropic/Anthropic.list',
      'https://raw.githubusercontent.com/HotKids/Rules/master/Surge/RULE-SET/Anthropic.list',
    ],
  },
];

const ipRuleTypes = new Set(['IP-CIDR', 'IP-CIDR6', 'IP-ASN', 'GEOIP']);
const supportedFlags = new Set(['no-resolve', 'extended-matching', 'force-remote-dns', 'no-alert']);

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

function buildMergedContent(ruleSet, rules) {
  return [
    `# NAME: ${ruleSet.name}`,
    '# FORMAT: Surge rule-set',
    `# SOURCES: ${ruleSet.sources.join('; ')}`,
    `# TOTAL: ${rules.length}`,
    ...rules,
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

  await writeRule(ruleSet.target, buildMergedContent(ruleSet, [...rules.keys()]));
  console.log(`Updated ${ruleSet.target} from ${ruleSet.urls.length} sources`);
}
