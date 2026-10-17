"""Audit tracked/staged files without printing secrets. Run before publishing."""
from pathlib import Path
import re, subprocess, sys

root = Path(__file__).resolve().parents[1]
paths = subprocess.check_output(['git', '-C', str(root), 'ls-files', '-z']).split(b'\0')
known = []
for name in ['.env', 'firmware/include/device_config.h', 'firmware/include/wifi_secrets.h']:
    file = root / name
    if not file.exists():
        continue
    for line in file.read_text().splitlines():
        match = re.match(r'^\s*(?:#define\s+)?(?:DEEPSEEK_API_KEY|TODO_TOKEN|TODO_ACCESS_TOKEN|WEATHER_WIFI_PASSWORD)\s*(?:=|\s)\s*[\"\']?([^\"\'\s]+)', line)
        if match and len(match[1]) >= 8 and not any(s in match[1].lower() for s in ['replace', 'your_', 'example']):
            known.append(match[1].encode())
patterns = [re.compile(rb'sk-[A-Za-z0-9]{20,}'), re.compile(rb'gh[pousr]_[A-Za-z0-9]{20,}'), re.compile(rb'github_pat_[A-Za-z0-9_]{30,}'), re.compile(rb'-----BEGIN (?:OPENSSH|RSA|EC|DSA) PRIVATE KEY-----')]
issues = []
for raw in paths:
    if not raw:
        continue
    name = raw.decode()
    file = root / name
    forbidden = name == '.env' or any(part in name.split('/') for part in ['node_modules', 'runtime', '.venv', '.pio', '.platformio', 'local-history']) or name.startswith(('data/', 'dist/', 'references/deepseek-harness/')) or name.endswith(('local.properties', 'device_config.h', 'wifi_secrets.h', 'local-toolchain.env', '.log'))
    if forbidden:
        issues.append((name, 'private/cache path'))
        continue
    data = file.read_bytes()
    if len(data) > 10 * 1024 * 1024:
        issues.append((name, 'oversized source artifact'))
    if any(secret in data for secret in known) or any(pattern.search(data) for pattern in patterns):
        issues.append((name, 'possible credential; value suppressed'))
    if (str(Path.home()).encode()+b'/') in data:
        issues.append((name, 'developer personal path/address'))
if issues:
    for name, reason in issues[:20]:
        print(f'FAIL: {name}: {reason}')
    sys.exit(1)
print(f'PASS: {sum(bool(p) for p in paths)} tracked files; no forbidden paths, known local credentials, key patterns or developer personal paths found')
