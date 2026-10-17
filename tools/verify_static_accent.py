"""Apply the user's current saved layout, then verify accent protocol guardrails.
--full explicitly permits one full refresh; otherwise sends only a partial update.
Does not create, complete, or rename tasks.
"""
import json,urllib.request,urllib.error,hashlib,datetime,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
saved=Path.home()/'Library/Application Support/MoJian/state.json'
before=saved.read_bytes();state=json.loads(before);settings=state['settings']
out=root/'data/red-accent-verification';out.mkdir(exist_ok=True,parents=True)
subprocess.run([str(root/'dist/墨间.app/Contents/MacOS/MoJian'),'--render-current',str(out)],check=True)
assert saved.read_bytes()==before,'App state changed during rendering; rerun with latest state'
frame=(out/'frame.bin').read_bytes();assert len(frame)==48000 and all(b==255 for b in frame[8000:10400])
env={k:v.strip().strip('"\'') for line in (root/'.env').read_text().splitlines() if '=' in line and not line.startswith('#') for k,v in [line.split('=',1)]}
origin=settings['deviceURL'].rstrip('/')
headers={'Authorization':'Bearer '+env['TODO_TOKEN']}
def request(path,body=None,extra=None):
 return urllib.request.urlopen(urllib.request.Request(origin+path,data=body,headers=headers|(extra or {})),timeout=90).read()
remote=json.loads(request('/api/local/state'));assert remote['accent_version_supported']=='mojian-red-v2'
layout='mac.calendar.red-v2' if state['afterHours'] else 'mac.'+settings['layout']+'.red-v2'
if not state['afterHours'] and settings['layout']=='custom':layout+='.'+str(int(settings['customRatio']*100))+'.'+'-'.join(settings['customModules'])
reference=datetime.datetime(2001,1,1,tzinfo=datetime.timezone.utc)
tasks=[{'id':t['id'],'title':t['title'],'due':(reference+datetime.timedelta(seconds=t['due'])).isoformat() if t.get('due') is not None else None} for t in state['tasks'] if not t['done']]
meta={'tasks':tasks,'layout_id':layout,'external_layout':True,'accent_version':'mojian-red-v2','accent_style':'calendar' if state['afterHours'] else settings['layout'],'content_key':hashlib.sha256(before).hexdigest(),'epoch_seconds':int(datetime.datetime.now().timestamp()),'updated_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
def commit(payload,metadata,full=False):
 boundary='MoJianAccentVerification'
 body=(f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n\r\n'+json.dumps(metadata,ensure_ascii=False)+f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="frame"; filename="frame.bin"\r\nContent-Type: application/octet-stream\r\n\r\n').encode()+payload+f'\r\n--{boundary}--\r\n'.encode()
 return request('/api/local/commit?full='+('1' if full else '0'),body,{'Content-Type':'multipart/form-data; boundary='+boundary})
commit(frame,meta,'--full' in sys.argv)
print('Applied current saved layout:',layout,'full='+str('--full' in sys.argv),flush=True)
base=request('/api/local/base');assert base==frame
if '--exercise-partial' in sys.argv:
    # Temporary test dot in the blank right margin, restored immediately.
    changed=bytearray(frame);changed[472*100+99]^=1
    commit(bytes(changed),meta);assert request('/api/local/base')==bytes(changed)
    commit(frame,meta);assert request('/api/local/base')==frame
    print('Small-window partial write and restore verified',flush=True)
for name,payload,metadata,code in [('black-in-red-band',frame[:8000]+bytes([0])+frame[8001:],meta,400),('red-version-change',frame,meta|{'accent_version':''},409),('red-style-change',frame,meta|{'accent_style':'calendar' if meta['accent_style']!='calendar' else 'focus'},409)]:
 try:commit(payload,metadata);raise AssertionError('Invalid update accepted')
 except urllib.error.HTTPError as e:assert e.code==code
assert request('/api/local/base')==frame
actual=json.loads(request('/api/local/state'));assert actual['tasks']==tasks and actual['accent_version']=='mojian-red-v2'
result={'layout_id':layout,'full':'--full' in sys.argv,'frame_bytes':len(frame),'task_count':len(tasks),'frame_readback_equal':True,'invalid_updates_rejected':True,'optical_confirmation':False}
(out/('full-result.json' if '--full' in sys.argv else 'partial-result.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False))
