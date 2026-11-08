"""Explicit live integration check. Imports current pending tasks; temporary probe removed.
Run with --device http://<ESP32-IP> --mac-pid <PID>. Never prints credentials.
"""
from pathlib import Path
import argparse,json,urllib.request,urllib.error,io,secrets,time,os,signal,sys
from datetime import datetime
from zoneinfo import ZoneInfo
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parents[1]
args=argparse.ArgumentParser();args.add_argument('--device',required=True);args.add_argument('--mac-pid',type=int,required=True);args=args.parse_args()
cfg=dict(line.split('=',1) for line in (root/'.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
def request(origin,path,body=None,content='application/json',auth=True):
 headers={'Content-Type':content}
 if auth:headers['Authorization']='Bearer '+cfg['TODO_TOKEN']
 req=urllib.request.Request(origin+path,data=body,headers=headers)
 with urllib.request.urlopen(req,timeout=60) as r:return r.read()
mac='http://127.0.0.1:8787';device=args.device.rstrip('/')
report=json.loads(request(mac,'/api/tasks'));tasks=[{'title':t['title'],'due':t['due']} for t in report['tasks'] if not t['done']][:4]
original=request(mac,'/api/device/frame')[:48000]
sys.path.insert(0,str(root/'server'));from dashboard import REGIONS,due_label
stamp=datetime.now(ZoneInfo('Asia/Shanghai'))
def compose(entries):
 im=Image.frombytes('1',(800,480),original);d=ImageDraw.Draw(im)
 def text(x,y,s,n=18):d.text((x,y),s,font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',n),fill=0)
 for name in ['next_task','todo_heading','task_summary']+[f'todo_{i}' for i in range(4)]:
  x,y,w,h=REGIONS[name];d.rectangle((x,y,x+w-1,y+h-1),fill=1)
 text(536,16,'独立待办 · 手机直写',15);text(536,43,entries[0]['title'][:11] if entries else '暂无待办',21);text(536,76,'内容保存在设备内',14)
 text(536,121,'待办清单',23);text(735,126,str(len(entries))+' 项',16)
 for i,t in enumerate(entries):
  y=164+i*58;d.rectangle((538,y+5,548,y+15),outline=0);text(558,y,t['title'][:11],18);text(558,y+27,due_label(t,stamp),13)
 text(536,436,f'{len(entries)} 项待办 · 独立模式',16)
 d.rectangle((24,464,775,479),fill=1);text(24,466,'独立模式：行情与天气保留旧值，截止时间以手机为准',10)
 return im.tobytes()
def commit(entries,full=False,payload=None):
 boundary='Desk'+secrets.token_hex(8);metadata=json.dumps({'tasks':entries,'updated_at':datetime.now().isoformat(),'epoch_seconds':int(time.time())},ensure_ascii=False)
 body=(f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n\r\n'+metadata+f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="frame"; filename="frame.bin"\r\nContent-Type: application/octet-stream\r\n\r\n').encode()+(payload if payload is not None else compose(entries))+f'\r\n--{boundary}--\r\n'.encode()
 return json.loads(request(device,'/api/local/commit?full='+str(int(full)),body,'multipart/form-data; boundary='+boundary))
try:request(device,'/api/local/state',auth=False);raise AssertionError('Unauthenticated access accepted')
except urllib.error.HTTPError as e:assert e.code==401
print('Unauthenticated access rejected',flush=True)
state=json.loads(request(device,'/api/local/state'))
assert state['storage_ready'];print('Standalone storage ready',flush=True)
commit(tasks,state['needs_full']);print('Initial standalone frame saved; real pending tasks imported:',len(tasks),flush=True)
os.kill(args.mac_pid,signal.SIGSTOP)
try:
 print('Mac service suspended for independent write test',flush=True)
 entries=tasks[:3]+[{'title':'直连临时验证 · 随后移除','due':None}]
 commit(entries);state=json.loads(request(device,'/api/local/state'));assert state['tasks']==entries
 print('Direct write while Mac stopped: passed',flush=True)
 commit(tasks);state=json.loads(request(device,'/api/local/state'));assert state['tasks']==tasks and state['local_mode']
 print('Temporary item removed; original pending tasks restored',flush=True)
 try:commit(tasks,payload=b'bad');raise AssertionError('Invalid frame accepted')
 except urllib.error.HTTPError as e:assert e.code==400
 assert json.loads(request(device,'/api/local/state'))['tasks']==tasks
 print('Truncated frame rejected without changing tasks',flush=True)
finally:os.kill(args.mac_pid,signal.SIGCONT);print('Mac service resumed; ESP32 stays in standalone mode',flush=True)
(root/'docs/standalone-verification.json').write_text(json.dumps({'device':device,'imported_task_count':len(tasks),'mac_stopped_write':True,'temporary_probe_removed':True,'malformed_frame_rejected':True,'local_mode':True},indent=2))
