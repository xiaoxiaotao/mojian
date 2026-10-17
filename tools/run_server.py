"""Load project-local settings without printing credentials."""
import os, runpy, sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
for line in (root/'.env').read_text().splitlines():
    if not line.strip() or line.lstrip().startswith('#'): continue
    key,sep,value=line.partition('=')
    if sep: os.environ[key.strip()]=value.strip().strip('"').strip("'")
sys.path.insert(0,str(root/'server'))
runpy.run_path(str(root/'server/app.py'),run_name='__main__')
