"""Fetch checksum-locked OFL fonts and package unmodified files + licenses."""
from pathlib import Path
import argparse,hashlib,json,shutil,urllib.request
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--destination',required=True,type=Path);args=p.parse_args()
cache=root/'tools/downloads/screen-fonts';cache.mkdir(parents=True,exist_ok=True)
args.destination.mkdir(parents=True,exist_ok=True)
manifest=root/'resources/fonts/manifest.json'
for font in json.loads(manifest.read_text())['fonts']:
 file=cache/font['file']
 study=root/'tools/downloads/font-study-2026-10-20'/font['file']
 if not file.exists() and study.exists():shutil.copy2(study,file)
 if not file.exists():
  with urllib.request.urlopen(font['url'],timeout=60) as r:data=r.read()
  if hashlib.sha256(data).hexdigest()!=font['sha256']:raise SystemExit('Font checksum mismatch: '+font['file'])
  file.write_bytes(data)
 if hashlib.sha256(file.read_bytes()).hexdigest()!=font['sha256']:raise SystemExit('Font checksum mismatch: '+font['file'])
 shutil.copy2(file,args.destination/font['file'])
for file in manifest.parent.glob('*-OFL.txt'):shutil.copy2(file,args.destination/file.name)
shutil.copy2(manifest,args.destination/'manifest.json')
print('Prepared three checksum-verified OFL screen fonts and licenses')
