const sources = [
  {
    target: 'ChinaDirect.list',
    url: 'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/ChinaMax/ChinaMax.list',
  },
  {
    target: 'Apple.list',
    url: 'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/Apple/Apple.list',
  },
  {
    target: 'Google.list',
    url: 'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/Google/Google.list',
  },
  {
    target: 'ChinaIPv4.list',
    url: 'https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Surge/ChinaIPsBGP/ChinaIPsBGP.list',
  },
  {
    target: 'ChinaIPv6.list',
    url: 'https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/ChinaIpV6.list',
  },
];

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

for (const source of sources) {
  const content = await fetchRule(source.url);
  await Bun.write(source.target, content).catch(async () => {
    const { writeFile } = await import('node:fs/promises');
    await writeFile(source.target, content, 'utf8');
  });
  console.log(`Updated ${source.target} from ${source.url}`);
}
