"""Build Surge rule sets from the PC's sing-box source rule sets.

Usage:
    python tools/build_surge.py --source <D:\\proxy\\data\\rule-sets>

Copies every publishable sing-box JSON into sing-box/ and writes the matching
Surge RULE-SET into surge/. Rules iOS cannot use (process matching) are left
out, and so are the PC-only and personal sets listed in SKIP.
"""
import argparse
import hashlib
import ipaddress
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Sets that are not published: process-only, PC-only (Surge uses 198.18/15 as
# its fake-IP pool) or personal (own node domains, own network addresses).
SKIP = {
    'reject-ip': 'PC only: rejects the fake-IP range',
    'direct-domain': 'personal: own node domains, kept in the profile instead',
    'direct-ip': 'personal: own network addresses, kept in the profile instead',
}

# Surge-only exclusions inside a published set.
EXCLUDE = {
    'Private-ip': {'198.18.0.0/15': 'Surge fake-IP pool'},
}

# Surge has no DOMAIN-REGEX. Every regex in the source must be listed here;
# an unknown one stops the build so it gets reviewed.
REGEX = {
    r'(^|\.)turn[0-9]*\.': [
        f'DOMAIN-WILDCARD,{p}turn{d}.*'
        for p in ('', '*.') for d in ('', '[0-9]', '[0-9][0-9]', '[0-9][0-9][0-9]')
    ],
    r'.+\.awsdns-cn-[0-9][0-9]\.(biz|com|net|top)$': [
        f'DOMAIN-WILDCARD,*.awsdns-cn-[0-9][0-9].{tld}' for tld in ('biz', 'com', 'net', 'top')
    ],
    r'.+\.awsdns-cn-[0-9][a-e0-9]\.cn$': ['DOMAIN-WILDCARD,*.awsdns-cn-[0-9][a-e0-9].cn'],
    r'^(.+\.)*zh\.okaapps\.com$': ['DOMAIN-SUFFIX,zh.okaapps.com'],
    r'^.+-mihayo\.akamaized\.net$': ['DOMAIN-WILDCARD,?*-mihayo.akamaized.net'],
    r'^cdn\d-epicgames-\d+\.file\.myqcloud\.com$': [
        'DOMAIN-WILDCARD,cdn[0-9]-epicgames-[0-9]*.file.myqcloud.com'
    ],
    r'^epicgames-download\d-\d+\.file\.myqcloud\.com$': [
        'DOMAIN-WILDCARD,epicgames-download[0-9]-[0-9]*.file.myqcloud.com'
    ],
    r'^r+[0-9]+(---|\.)sn-(2x3|ni5|j5o)\w{5}\.googlevideo\.com$': [
        f'DOMAIN-WILDCARD,r*[0-9]{sep}sn-{n}?????.googlevideo.com'
        for sep in ('---', '.') for n in ('2x3', 'ni5', 'j5o')
    ],
    r'^r+[0-9]+(---|\.)sn-(2x3|ni5|j5o)\w{5}\.xn--ngstr-lra8j\.com$': [
        f'DOMAIN-WILDCARD,r*[0-9]{sep}sn-{n}?????.xn--ngstr-lra8j.com'
        for sep in ('---', '.') for n in ('2x3', 'ni5', 'j5o')
    ],
    r'^chatgpt-async-webps-prod-\S+-\d+\.webpubsub\.azure\.com$': [
        'DOMAIN-WILDCARD,chatgpt-async-webps-prod-?*-[0-9]*.webpubsub.azure.com'
    ],
}
# ^.+\.<suffix>$ means "any subdomain of <suffix>", which DOMAIN-WILDCARD says exactly.
SUBDOMAIN_REGEX = re.compile(r'^\^\.\+\\\.((?:[a-z0-9-]+\\\.)*[a-z0-9-]+)\$$')

IGNORED_FIELDS = {'process_name', 'process_path', 'process_path_regex', 'package_name'}


def regex_rules(rx):
    if rx in REGEX:
        return REGEX[rx]
    m = SUBDOMAIN_REGEX.match(rx)
    if m:
        return ['DOMAIN-WILDCARD,*.' + m.group(1).replace('\\.', '.')]
    raise SystemExit(f'no Surge conversion for domain_regex {rx!r}')


def ip_rule(cidr):
    net = ipaddress.ip_network(cidr, strict=False)
    kind = 'IP-CIDR' if net.version == 4 else 'IP-CIDR6'
    return f'{kind},{net.with_prefixlen},no-resolve'


def default_rule(rule, exclude):
    """Return (lines, any_or_all) for one sing-box headless default rule."""
    unknown = set(rule) - {'domain', 'domain_suffix', 'domain_keyword', 'domain_regex',
                           'ip_cidr', 'network', 'port', 'invert'} - IGNORED_FIELDS
    if unknown:
        raise SystemExit(f'unsupported fields {sorted(unknown)}')
    if set(rule) & IGNORED_FIELDS:
        if set(rule) - IGNORED_FIELDS - {'invert'}:
            raise SystemExit('process matching mixed with other fields')
        return []
    domains = [f'DOMAIN,{d}' for d in rule.get('domain', [])]
    for s in rule.get('domain_suffix', []):
        domains.append(f'DOMAIN-WILDCARD,*{s}' if s.startswith('.') else f'DOMAIN-SUFFIX,{s}')
    domains += [f'DOMAIN-KEYWORD,{k}' for k in rule.get('domain_keyword', [])]
    for rx in rule.get('domain_regex', []):
        domains += regex_rules(rx)
    ips = [ip_rule(c) for c in rule.get('ip_cidr', []) if c not in exclude]
    # sing-box ORs the domain fields together and ANDs the other field groups.
    groups = [g for g in (domains + ips,) if g]
    if 'network' in rule:
        nets = rule['network'] if isinstance(rule['network'], list) else [rule['network']]
        groups.append([f'PROTOCOL,{n.upper()}' for n in nets])
    if 'port' in rule:
        groups.append([f'DEST-PORT,{p}' for p in rule['port']])
    if rule.get('invert'):
        return [f'NOT,(({combine(groups)}))']
    if len(groups) == 1:
        return groups[0]
    if len(groups) == 2 and len(groups[1]) > 1 and len(groups[0]) == 1:
        # e.g. UDP on one of several ports: one AND line per port
        return [f'AND,(({groups[0][0]}),({p}))' for p in groups[1]]
    return [combine(groups)]


def combine(groups):
    parts = []
    for g in groups:
        parts.append(g[0] if len(g) == 1 else 'OR,(' + ','.join(f'({x})' for x in g) + ')')
    return parts[0] if len(parts) == 1 else 'AND,(' + ','.join(f'({p})' for p in parts) + ')'


def logical_rule(rule, exclude):
    sub = []
    for r in rule['rules']:
        lines = logical_rule(r, exclude) if r.get('type') == 'logical' else default_rule(r, exclude)
        if len(lines) != 1:
            raise SystemExit('logical sub-rule must convert to exactly one Surge rule')
        sub.append(lines[0])
    op = {'and': 'AND', 'or': 'OR'}[rule['mode']]
    line = f'{op},(' + ','.join(f'({s})' for s in sub) + ')'
    return [f'NOT,(({line}))'] if rule.get('invert') else [line]


def convert(data, exclude):
    out, seen = [], set()
    for rule in data['rules']:
        lines = logical_rule(rule, exclude) if rule.get('type') == 'logical' else default_rule(rule, exclude)
        for line in lines:
            if line not in seen:
                seen.add(line)
                out.append(line)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--source', required=True, type=Path, help='directory with the PC sing-box *.json rule sets')
    args = ap.parse_args()
    (ROOT / 'sing-box').mkdir(exist_ok=True)
    (ROOT / 'surge').mkdir(exist_ok=True)
    manifest = {}
    for src in sorted(args.source.glob('*.json'), key=lambda p: p.name.lower()):
        tag = src.stem
        raw = src.read_bytes().removeprefix(b'\xef\xbb\xbf').replace(b'\r\n', b'\n')
        if tag in SKIP:
            print(f'skip {tag}: {SKIP[tag]}')
            continue
        exclude = EXCLUDE.get(tag, {})
        lines = convert(json.loads(raw), exclude)
        if not lines:
            print(f'skip {tag}: empty or process-only')
            continue
        sha = hashlib.sha256(raw).hexdigest()
        (ROOT / 'sing-box' / src.name).write_bytes(raw)
        header = [f'# NAME: {tag}', f'# SOURCE: sing-box/{src.name} (sha256 {sha})', f'# RULES: {len(lines)}']
        header += [f'# OMITTED: {k} ({v})' for k, v in exclude.items()]
        (ROOT / 'surge' / f'{tag}.list').write_text('\n'.join(header + lines) + '\n', encoding='utf-8', newline='\n')
        manifest[tag] = {'source_sha256': sha, 'surge_rules': len(lines)}
    (ROOT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(f'{len(manifest)} rule sets written')


if __name__ == '__main__':
    main()
