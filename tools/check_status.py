"""Show safe local service and device status, never keys."""
from pathlib import Path
import urllib.request,json
root=Path(__file__).resolve().parents[1]
cfg=dict(line.split('=',1) for line in (root/'.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
req=urllib.request.Request('http://127.0.0.1:'+cfg.get('PORT','8787')+'/api/tasks',headers={'Authorization':'Bearer '+cfg['TODO_TOKEN']})
with urllib.request.urlopen(req,timeout=10) as response: data=json.load(response)
print('DeepSeek configured:',bool(cfg.get('DEEPSEEK_API_KEY')))
print('Pending tasks:',sum(not task['done'] for task in data['tasks']))
print('Device reported:',bool(data['device']))
print('Current frame displayed:',bool(data['device'] and data['device']['revision']==data['revision']))
if data['device']: print('Last device report:',data['device']['seen'])
