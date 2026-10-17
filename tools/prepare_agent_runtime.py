"""Fetch the pinned official arm64 Node archive and verify its recorded SHA256."""
from pathlib import Path
import hashlib,tarfile,urllib.request
root=Path(__file__).resolve().parents[1]/'agent-engine'
url,checksum=(root/'NODE-SOURCE.txt').read_text().splitlines()
assert url.startswith('https://nodejs.org/dist/') and url.endswith('-darwin-arm64.tar.gz')
expected=checksum.removeprefix('sha256 ')
if (root/'runtime/bin/node').exists():
    print('Pinned Node runtime already prepared');raise SystemExit(0)
archive=root/Path(url).name
urllib.request.urlretrieve(url,archive)
if hashlib.sha256(archive.read_bytes()).hexdigest()!=expected:
    archive.unlink();raise SystemExit('Node archive checksum mismatch')
with tarfile.open(archive) as tar:
    tar.extractall(root,filter='data')
(root/archive.name.removesuffix('.tar.gz')).rename(root/'runtime')
archive.unlink()
print('Prepared verified official arm64 Node runtime')
