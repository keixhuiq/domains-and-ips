"""Build iOS-compatible sing-box rule sets from this repository's source lists."""
import argparse
import hashlib
import ipaddress
import json
import subprocess
from pathlib import Path

SERVICES = ['Claude', 'OpenAI', 'TikTok', 'Crunchyroll', 'Abema', 'UNEXT',
            'bookwalker.jp', 'bookwalker.tw', 'Amazon', 'Crypto', 'CustomProxy']
FIELDS = {'DOMAIN': 'domain', 'DOMAIN-SUFFIX': 'domain_suffix',
          'DOMAIN-KEYWORD': 'domain_keyword', 'IP-CIDR': 'ip_cidr',
          'IP-CIDR6': 'ip_cidr'}


def convert(path):
    values = {}
    skipped = []
    for line_no, raw in enumerate(path.read_text(encoding='utf-8-sig').splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith(('#', '//')):
            continue
        parts = [p.strip() for p in line.split(',')]
        kind = parts[0]
        if kind == 'PROCESS-NAME':
            skipped.append({'line': line_no, 'type': kind, 'value': parts[1],
                            'reason': 'Process matching is unavailable in the iOS App Store client.'})
            continue
        if kind not in FIELDS or len(parts) < 2 or not parts[1]:
            raise ValueError(f'{path}:{line_no}: unsupported or malformed rule')
        if any(p != 'no-resolve' for p in parts[2:]):
            raise ValueError(f'{path}:{line_no}: unexpected rule option')
        key = FIELDS[kind]
        value = str(ipaddress.ip_network(parts[1], strict=False)) if key == 'ip_cidr' else parts[1]
        if value not in values.setdefault(key, []):
            values[key].append(value)
    # Separate field families explicitly: each source line has OR semantics.
    rules = [{key: value} for key, value in values.items()]
    if not rules:
        raise ValueError(f'{path}: empty rules')
    return {'version': 3, 'rules': rules}, skipped


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sing-box', required=True, help='Path to sing-box 1.11+ executable')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    manifest = {'format_version': 3, 'profile': 'iOS App Store',
                'text_hash_encoding': 'UTF-8 without BOM, LF line endings', 'services': {}}
    for service in SERVICES:
        source = root / service / 'DOMAIN.list'
        content, skipped = convert(source)
        target = source.with_name('sing-box.json')
        target.write_text(json.dumps(content, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
        binary = source.with_name('sing-box.srs')
        subprocess.run([args.sing_box, 'rule-set', 'compile', '--output', str(binary), str(target)], check=True)
        manifest['services'][service] = {
            'source': f'{service}/DOMAIN.list',
            'source_sha256': hashlib.sha256(source.read_text(encoding='utf-8-sig').encode('utf-8')).hexdigest(),
            'rule_count': sum(len(v) for rule in content['rules'] for v in rule.values()),
            'json_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
            'srs_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
            'omitted_rules': skipped,
        }
    (root / 'sing-box-manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(f'Built {len(SERVICES)} source and binary rule sets.')


if __name__ == '__main__':
    main()
