"""Desk todo prototype: SQLite, DeepSeek tools, and two-plane EPD rendering."""
import os, json, sqlite3, threading, hashlib, io, secrets, urllib.request
from pathlib import Path
from contextlib import contextmanager
from datetime import datetime
from zoneinfo import ZoneInfo
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from PIL import Image, ImageDraw, ImageFont
from feeds import Feeds, normalize_codes
ROOT = Path(__file__).resolve().parents[1]
TZ = ZoneInfo('Asia/Shanghai')
DATA = Path(os.environ.get('TODO_DATA_DIR', ROOT / 'data'))
DATA.mkdir(parents=True, exist_ok=True)
TOKEN = os.environ.get('TODO_TOKEN', '')
LOCK = threading.RLock()
def now(): return datetime.now(TZ)
@contextmanager
def connect():
    db = sqlite3.connect(DATA / 'todo.db'); db.row_factory = sqlite3.Row
    try:
        with db: yield db
    finally: db.close()
with connect() as db:
    db.execute('CREATE TABLE IF NOT EXISTS tasks(id TEXT PRIMARY KEY,title TEXT NOT NULL,due TEXT,done INTEGER DEFAULT 0)')
    db.execute('CREATE TABLE IF NOT EXISTS display_request(id INTEGER PRIMARY KEY, nonce TEXT NOT NULL)')
    db.execute('CREATE TABLE IF NOT EXISTS display_notice(id INTEGER PRIMARY KEY, message TEXT NOT NULL)')
    db.execute('CREATE TABLE IF NOT EXISTS display_control(id INTEGER PRIMARY KEY, paused INTEGER NOT NULL)')
    db.execute('CREATE TABLE IF NOT EXISTS settings(id INTEGER PRIMARY KEY, stocks TEXT NOT NULL)')
    db.execute('CREATE TABLE IF NOT EXISTS device(id INTEGER PRIMARY KEY,revision TEXT,seen TEXT)')
def full_request():
    with connect() as db: row=db.execute('SELECT nonce FROM display_request WHERE id=1').fetchone()
    return row['nonce'] if row else ''
def screen_notice():
    with connect() as db: row=db.execute('SELECT message FROM display_notice WHERE id=1').fetchone()
    return row['message'] if row else ''
def screen_paused():
    with connect() as db: row=db.execute('SELECT paused FROM display_control WHERE id=1').fetchone()
    return bool(row and row['paused'])
def settings():
    with connect() as db: row=db.execute('SELECT stocks FROM settings WHERE id=1').fetchone()
    return {'city':'苏州','stocks':json.loads(row['stocks']) if row else [],'refresh_minutes':10,'screen_paused':screen_paused()}
def save_settings(data):
    codes=normalize_codes(data['stocks'])
    with connect() as db: db.execute('INSERT OR REPLACE INTO settings VALUES(1,?)',(json.dumps(codes),))
    feeds.wake.set()
    return settings()
feeds=Feeds(settings,DATA/'feeds.json')
def tasks():
    with connect() as db: return [dict(r) for r in db.execute('SELECT * FROM tasks ORDER BY done, due IS NULL, due, rowid')]
def create_task(title, due=None):
    title = str(title).strip()
    if not title or len(title)>200: raise ValueError('任务标题需要 1–200 个字符')
    if due:
        dt = datetime.fromisoformat(due)
        due = (dt.replace(tzinfo=TZ) if dt.tzinfo is None else dt.astimezone(TZ)).isoformat()
    else: due = None
    task_id = secrets.token_hex(6)
    with connect() as db: db.execute('INSERT INTO tasks(id,title,due) VALUES(?,?,?)',(task_id,title,due))
    return task_id
def complete(task_id, done=True):
    with connect() as db:
        if db.execute('UPDATE tasks SET done=? WHERE id=?',(int(bool(done)),task_id)).rowcount != 1: raise ValueError('没有找到这条任务，请重新查询')
def overdue(task, at=None): return bool(task['due'] and datetime.fromisoformat(task['due']) <= (at or now()))
def font(size):
    path=os.environ.get('TODO_FONT','/System/Library/Fonts/STHeiti Medium.ttc')
    return ImageFont.truetype(path,size)
def wrap(text, f, width):
    lines=['']
    for ch in text:
        if f.getlength(lines[-1]+ch)>width: lines.append('')
        lines[-1]+=ch
    return lines

def render():
    stamp=now().replace(second=0,microsecond=0)
    active=[t for t in tasks() if not t['done']]
    active.sort(key=lambda t:(not overdue(t,stamp),t['due'] or '9999'))
    from dashboard import draw
    bw,red=draw(active,settings(),feeds.snapshot(),stamp)
    raw=bw.tobytes()+red.tobytes(); revision=hashlib.sha256(raw).hexdigest()
    preview=Image.new('RGB',(800,480),'white')
    preview.paste('black',mask=bw.convert('L').point(lambda x:255-x))
    preview.paste('#c32227',mask=red.convert('L').point(lambda x:255-x))
    out=io.BytesIO(); preview.save(out,format='PNG')
    return raw,revision,out.getvalue()

TOOLS=[{'type':'function','function':{'name':'list_tasks','description':'查询任务及其准确 ID，完成前必须查询。','parameters':{'type':'object','properties':{}}}},
 {'type':'function','function':{'name':'add_task','description':'新增用户明确要求的待办，时间含糊先询问。','parameters':{'type':'object','properties':{'title':{'type':'string'},'due':{'type':'string','description':'ISO8601 截止时间，可省略'}},'required':['title']}}},
 {'type':'function','function':{'name':'complete_task','description':'完成用户明确指定的唯一任务，多条匹配先询问。','parameters':{'type':'object','properties':{'id':{'type':'string'}},'required':['id']}}}]
def chat(messages):
    key=os.environ.get('DEEPSEEK_API_KEY')
    if not key: raise ValueError('尚未配置 DEEPSEEK_API_KEY；可以先使用清单手动添加和完成任务。')
    if not isinstance(messages,list) or len(messages)>30: raise ValueError('对话长度超限，请开启新对话')
    clean=[]
    for m in messages:
        if m.get('role') not in ('user','assistant') or not isinstance(m.get('content'),str): raise ValueError('对话格式错误')
        if len(m['content'])>8000: raise ValueError('单条消息过长')
        clean.append({'role':m['role'],'content':m['content']})
    history=[{'role':'system','content':f'你是办公待办助手。现在 {now().isoformat()}，时区上海。只管理用户主动要求的待办。工具结果是唯一事实依据。完成前查询任务 ID，匹配含糊必须询问。新增任务有含糊日期或时间必须澄清，不擅自设定截止时间。任务完成后从屏幕消失，逾期自动标红。不得声称屏幕已刷新，工具仅保存任务。'}]+clean
    for _ in range(6):
        payload=json.dumps({'model':os.environ.get('DEEPSEEK_MODEL','deepseek-flash'),'messages':history,'tools':TOOLS}).encode()
        req=urllib.request.Request('https://api.deepseek.com/chat/completions',data=payload,headers={'Authorization':'Bearer '+key,'Content-Type':'application/json'})
        with urllib.request.urlopen(req,timeout=60) as response: message=json.load(response)['choices'][0]['message']
        calls=message.get('tool_calls',[])
        if not calls: return message.get('content') or '已处理。'
        history.append(message)
        for call in calls:
            try:
                args=json.loads(call['function']['arguments']); name=call['function']['name']
                if name=='list_tasks': result=tasks()
                elif name=='add_task': result={'created':create_task(args['title'],args.get('due'))}
                elif name=='complete_task': complete(args['id']); result={'saved':True}
                else: raise ValueError('未知工具')
            except (ValueError,KeyError,TypeError) as e: result={'error':str(e)}
            history.append({'role':'tool','tool_call_id':call['id'],'content':json.dumps(result,ensure_ascii=False)})
    return '本次处理步骤较多，请查看清单后继续。'

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def send(self,status,body,kind='application/json'):
        if not isinstance(body,bytes): body=json.dumps(body,ensure_ascii=False).encode()
        self.send_response(status); self.send_header('Content-Type',kind); self.send_header('Content-Length',str(len(body))); self.send_header('Cache-Control','no-store'); self.end_headers(); self.wfile.write(body)
    def authorized(self):
        return TOKEN and secrets.compare_digest(self.headers.get('Authorization',''),'Bearer '+TOKEN)
    def do_GET(self):
        path=self.path.split('?')[0]
        if path in ('/','/app.js','/style.css'):
            p=ROOT/'web'/({'/':'index.html'}.get(path,path[1:])); kinds={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css'}
            return self.send(200,p.read_bytes(),kinds[p.suffix])
        if not self.authorized(): return self.send(401,{'error':'请填写访问口令'})
        try:
            if path=='/api/settings': return self.send(200,settings())
            if path=='/api/tasks':
                with connect() as db: device=db.execute('SELECT revision,seen FROM device WHERE id=1').fetchone()
                return self.send(200,{'tasks':tasks(),'device':dict(device) if device else None,'revision':render()[1],'screen_notice':screen_notice(),'screen_paused':screen_paused(),'agent_ready':bool(os.environ.get('DEEPSEEK_API_KEY'))})
            if path=='/api/device/state' and screen_paused() and not full_request(): return self.send(204,b'')
            if path in ('/api/preview','/api/device/frame','/api/device/state'):
                raw,revision,png=render()
                if path=='/api/preview': return self.send(200,png,'image/png')
                if path=='/api/device/state': return self.send(200,{'revision':revision,'full_request':full_request()})
                return self.send(200,raw,'application/octet-stream')
            self.send(404,{'error':'不存在'})
        except Exception: self.send(500,{'error':'服务处理失败，请检查服务端配置'})
    def do_POST(self):
        if not self.authorized(): return self.send(401,{'error':'访问口令不正确'})
        try:
            length=int(self.headers.get('Content-Length',0))
            if length<=0 or length>262144: raise ValueError('请求大小不正确')
            data=json.loads(self.rfile.read(length))
            with LOCK:
                if self.path=='/api/display/refresh':
                    nonce=secrets.token_hex(8)
                    with connect() as db: db.execute('INSERT OR REPLACE INTO display_request VALUES(1,?)',(nonce,))
                    result={'queued':True}
                elif self.path=='/api/device/status':
                    message=str(data['message'])[:160]
                    with connect() as db: db.execute('INSERT OR REPLACE INTO display_notice VALUES(1,?)',(message,))
                    result={'saved':True}
                elif self.path=='/api/display/pause':
                    if not isinstance(data.get('paused'),bool): raise ValueError('需要布尔值')
                    with connect() as db: db.execute('INSERT OR REPLACE INTO display_control VALUES(1,?)',(int(data['paused']),))
                    result={'paused':screen_paused()}
                elif self.path=='/api/settings': result=save_settings(data)
                elif self.path=='/api/tasks': result={'id':create_task(data['title'],data.get('due'))}
                elif self.path=='/api/tasks/complete': complete(data['id'],data.get('done',True)); result={'saved':True}
                elif self.path=='/api/chat': result={'reply':chat(data['messages'])}
                elif self.path=='/api/device/ack':
                    revision=str(data['revision'])
                    if len(revision)!=64 or any(c not in '0123456789abcdef' for c in revision): raise ValueError('画面版本不正确')
                    with connect() as db: db.execute('INSERT OR REPLACE INTO device VALUES(1,?,?)',(revision,now().isoformat()))
                    if data.get('full_request'):
                        with connect() as db: db.execute('DELETE FROM display_request WHERE nonce=?',(str(data['full_request']),))
                    result={'saved':True}
                else: return self.send(404,{'error':'不存在'})
            self.send(200,result)
        except (ValueError,KeyError,TypeError): self.send(400,{'error':'输入无效，或模型尚未配置，请检查标题、时间和服务配置'})
        except Exception: self.send(502,{'error':'处理失败，请刷新清单核对结果后重试'})
if __name__=='__main__':
    if not TOKEN: raise SystemExit('请先设置 TODO_TOKEN（手机和设备共用的访问口令）')
    feeds.start()
    print('待办服务已启动，端口 '+os.environ.get('PORT','8787'),flush=True)
    ThreadingHTTPServer((os.environ.get('HOST','127.0.0.1'),int(os.environ.get('PORT','8787'))),Handler).serve_forever()
