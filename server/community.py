"""Optional self-hosted MoJian community hub. Data-only templates/plugins, reviewed inbox.
Run: python3 server/community.py --data data/community --port 8788
Defaults to loopback; put a TLS reverse proxy in front for remote access.
Credentials are generated into a private file, never printed or embedded in templates.
"""
import argparse, hashlib, hmac, json, os, secrets, sqlite3, threading, time
from contextlib import contextmanager
from datetime import date
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

VISUAL = {'layout','ratio','scene','cardsVersion','card1','card2','weeklyGoal','note','deskStatus','statusNote'}
LAYOUTS = {'focus','agenda','minimal','overview','pomodoro','living','custom','calendar'}
CARDS = {'plant','week','countdown','outdoor','status','note','nextEvent','commute','habits','inspiration','plugin'}
def text(value, limit):
    if not isinstance(value, str) or not value.strip() or len(value)>limit: raise ValueError('文字为空或过长')
    return value.strip()
def template(value):
    if value.get('schema')!='mojian-template-v1': raise ValueError('模板版本不支持')
    source=value.get('settings',{}); settings={k:v for k,v in source.items() if k in VISUAL}
    if settings.get('layout') not in LAYOUTS: raise ValueError('排版不支持')
    for key, low, high, default in [('ratio',40,75,67),('weeklyGoal',1,999,20)]:
        n=settings.get(key,default)
        if type(n) is not int or not low<=n<=high: raise ValueError('模板数字超出范围')
    for key in ('card1','card2'):
        if key in settings and settings[key] not in CARDS: raise ValueError('卡片不支持')
    for key,limit in [('note',100),('deskStatus',30),('statusNote',30)]:
        if not isinstance(settings.get(key,''),str) or len(settings.get(key,''))>limit: raise ValueError('模板文字过长')
    return {'schema':'mojian-template-v1','name':text(value.get('name'),30),'settings':settings}
def plugin(value):
    kind=value.get('kind')
    if kind not in ('text','countdown','daily'): raise ValueError('仅支持text/countdown/daily数据插件，不执行脚本')
    out={'schema':'mojian-card-v1','name':text(value.get('name'),30),'kind':kind}
    if kind=='countdown': out.update(title=text(value.get('title'),30),date=date.fromisoformat(value.get('date','')).isoformat())
    elif kind=='text': out['text']=text(value.get('text'),100)
    else:
        items=value.get('items',[])
        if not isinstance(items,list) or not 1<=len(items)<=31: raise ValueError('每日短句1至31条')
        out['items']=[text(v,100) for v in items]
    return out

def shared(value):
    """LWW register entries; each completion is keyed by task id, undo is a tombstone.
    Timestamps are epoch ms, tie breaks canonical payload; no summing client totals.
    """
    result={}; now=int(time.time()*1000)
    for kind,limit in [('completions',4096),('habits',32),('dates',128)]:
        items=value.get(kind,{})
        if not isinstance(items,dict) or len(items)>limit: raise ValueError('共享记录过多')
        result[kind]={}
        for key,entry in items.items():
            text(key,100)
            if not isinstance(entry,dict) or type(entry.get('stamp')) is not int or not 0<entry['stamp']<=now+300000: raise ValueError('记录时间无效')
            e={'stamp':entry['stamp'],'deleted':bool(entry.get('deleted',False))}
            if kind=='completions': e['completedAt']=int(entry.get('completedAt',entry['stamp']))
            elif not e['deleted']:
                e['title']=text(entry.get('title'),20 if kind=='habits' else 30)
                if kind=='dates': e['date']=date.fromisoformat(entry.get('date','')).isoformat()
                else:
                    days=entry.get('days',{})
                    if not isinstance(days,dict) or len(days)>56: raise ValueError('打卡最多56天')
                    e['days']={}
                    for day,v in days.items():
                        date.fromisoformat(day)
                        if not isinstance(v,dict) or type(v.get('stamp')) is not int or not 0<v['stamp']<=now+300000: raise ValueError('打卡时间无效')
                        e['days'][day]={'stamp':v['stamp'],'checked':bool(v.get('checked',False))}
            result[kind][key]=e
        if kind in ('habits','dates') and sum(not e.get('deleted') for e in result[kind].values())>(3 if kind=='habits' else 12): raise ValueError('有效习惯或日期过多')
    return result

def winner(a,b):
    return max((a,b), key=lambda x:(x.get('stamp',0),json.dumps(x,sort_keys=True)))
def merge(a,b):
    out={}
    for kind in ('completions','habits','dates'):
        out[kind]=dict(a.get(kind,{}))
        for key,value in b.get(kind,{}).items():
            old=out[kind].get(key)
            if old is None: out[kind][key]=value;continue
            chosen=dict(winner(old,value))
            if kind=='habits' and not chosen.get('deleted'):
                days=dict(old.get('days',{}))
                for day,mark in value.get('days',{}).items(): days[day]=winner(days[day],mark) if day in days else mark
                chosen['days']=dict(sorted(days.items())[-56:])
            out[kind][key]=chosen
    # Validate combined limits too; never truncate silently.
    return shared(out)

class Hub:
    def __init__(self, directory):
        self.directory=Path(directory);self.directory.mkdir(parents=True,exist_ok=True);self.directory.chmod(0o700)
        self.lock=threading.RLock();self.credentials=self.directory/'credentials.json'
        if not self.credentials.exists():
            fd=os.open(self.credentials,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
            with os.fdopen(fd,'w') as f: json.dump({'owner':secrets.token_urlsafe(32),'invite':secrets.token_urlsafe(24)},f)
        self.tokens=json.loads(self.credentials.read_text())
        with self.db() as db:
            db.execute('CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY,revision INTEGER,body TEXT)')
            db.execute('INSERT OR IGNORE INTO state VALUES(1,0,?)',(json.dumps(shared({})),))
            db.execute('CREATE TABLE IF NOT EXISTS objects(kind TEXT,id TEXT,body TEXT,PRIMARY KEY(kind,id))')
            db.execute('CREATE TABLE IF NOT EXISTS inbox(id TEXT PRIMARY KEY,body TEXT,created INTEGER,status TEXT)')
    @contextmanager
    def db(self):
        db=sqlite3.connect(self.directory/'hub.db')
        try:
            with db: yield db
        finally: db.close()
    def state(self):
        with self.db() as db:
            rev,body=db.execute('SELECT revision,body FROM state WHERE id=1').fetchone()
        return {'revision':rev,'data':json.loads(body)}
    def exchange(self,value):
        with self.lock,self.db() as db:
            rev,body=db.execute('SELECT revision,body FROM state WHERE id=1').fetchone()
            result=merge(json.loads(body),shared(value.get('data',{})))
            if result!=json.loads(body): rev+=1;db.execute('UPDATE state SET revision=?,body=? WHERE id=1',(rev,json.dumps(result)))
        return {'revision':rev,'data':result}
    def objects(self,kind):
        with self.db() as db: return [dict(id=k,**json.loads(b)) for k,b in db.execute('SELECT id,body FROM objects WHERE kind=? ORDER BY id',(kind,))]
    def save(self,kind,value):
        value=template(value) if kind=='templates' else plugin(value)
        key=hashlib.sha256(json.dumps(value,sort_keys=True).encode()).hexdigest()[:24]
        with self.lock,self.db() as db:
            if db.execute('SELECT COUNT(*) FROM objects WHERE kind=?',(kind,)).fetchone()[0]>=100 and not db.execute('SELECT 1 FROM objects WHERE kind=? AND id=?',(kind,key)).fetchone(): raise ValueError('最多100个扩展')
            db.execute('INSERT OR REPLACE INTO objects VALUES(?,?,?)',(kind,key,json.dumps(value)))
        return dict(id=key,**value)
    def message(self,value):
        body={'sender':text(value.get('sender'),30),'text':text(value.get('text'),100)}
        with self.lock,self.db() as db:
            if db.execute("SELECT COUNT(*) FROM inbox WHERE created>?",(int(time.time())-3600,)).fetchone()[0]>=30: raise ValueError('留言过于频繁，请稍后重试')
            key=secrets.token_hex(12);db.execute('INSERT INTO inbox VALUES(?,?,?,?)',(key,json.dumps(body),int(time.time()),'pending'))
        return {'id':key,'status':'pending'}
    def inbox(self):
        with self.db() as db: return [dict(id=k,created=t,status=s,**json.loads(b)) for k,b,t,s in db.execute("SELECT id,body,created,status FROM inbox ORDER BY created DESC LIMIT 100")]


INBOX_FORM = """<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>给墨间留一句话</title><style>body{font:16px system-ui;background:#f6f5ef;color:#293b31;margin:36px auto;padding:20px;max-width:480px}form{display:grid;gap:16px;background:white;padding:28px;border-radius:20px}input,textarea,button{font:inherit;padding:14px;border:1px solid #ccd5ce;border-radius:10px}button{background:#456452;color:white;cursor:pointer}small{color:#66756c}</style><h1>留一句话，在桌面相见。</h1><p>留言先送到主人的收件箱，经确认后才会显示。</p><form><label>邀请凭据<input id="token" type="password" autocomplete="off" required></label><label>你的称呼<input id="sender" maxlength="30" required></label><label>留言<textarea id="message" maxlength="100" required></textarea></label><button>送到收件箱</button><small>凭据不会存入浏览器或网址。请使用主人提供的服务地址。</small><output id="result"></output></form><script>document.querySelector('form').onsubmit=async e=>{e.preventDefault();let b=document.querySelector('button');b.disabled=true;try{let r=await fetch('/v1/messages',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+document.querySelector('#token').value},body:JSON.stringify({sender:document.querySelector('#sender').value,text:document.querySelector('#message').value})});document.querySelector('#result').textContent=r.ok?'已送达，等待主人确认。':'发送失败，请检查邀请凭据或稍后重试。';if(r.ok)document.querySelector('#message').value=''}catch(e){document.querySelector('#result').textContent='连接失败，请稍后重试。'}finally{b.disabled=false}};</script></html>"""

class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args): pass # Never log Authorization/invite tokens or message bodies.
    def reply(self,code,value):
        body=json.dumps(value,ensure_ascii=False).encode();self.send_response(code);self.send_header('Content-Type','application/json; charset=utf-8');self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
    def route(self):
        if self.command=='GET' and self.path=='/':
            page=INBOX_FORM.encode();self.send_response(200);self.send_header('Content-Type','text/html; charset=utf-8');self.send_header('Content-Length',str(len(page)));self.end_headers();self.wfile.write(page);return
        hub=self.server.hub
        token=self.headers.get('Authorization','').removeprefix('Bearer ')
        owner=hmac.compare_digest(token,hub.tokens['owner']);invite=hmac.compare_digest(token,hub.tokens['invite'])
        if not owner and not (invite and self.command=='POST' and self.path=='/v1/messages'): return self.reply(401,{'error':'授权失败'})
        body={}
        if self.command in ('POST','PUT'):
            try: length=int(self.headers.get('Content-Length','0'))
            except ValueError: return self.reply(400,{'error':'数据长度无效'})
            if length<=0 or length>524288:return self.reply(413,{'error':'数据长度超限'})
            body=json.loads(self.rfile.read(length))
            if not isinstance(body,dict): raise ValueError('需要JSON对象')
        if self.path=='/v1/state':
            if self.command=='GET':return self.reply(200,hub.state())
            if self.command=='POST':return self.reply(200,hub.exchange(body))
        if self.path in ('/v1/templates','/v1/plugins'):
            kind=self.path.split('/')[-1]
            if self.command=='GET':return self.reply(200,{'items':hub.objects(kind)})
            if self.command=='POST':return self.reply(200,hub.save(kind,body))
        if self.path=='/v1/messages':
            if self.command=='GET':return self.reply(200,{'items':hub.inbox()})
            if self.command=='POST':return self.reply(200,hub.message(body))
        if self.path.startswith('/v1/messages/') and self.command=='PUT':
            status=body.get('status')
            if status not in ('accepted','dismissed'):raise ValueError('状态无效')
            with hub.lock,hub.db() as db:
                if db.execute('UPDATE inbox SET status=? WHERE id=?',(status,self.path.split('/')[-1])).rowcount!=1:return self.reply(404,{'error':'留言不存在'})
            return self.reply(200,{'status':status})
        return self.reply(404,{'error':'接口不存在'})
    def handle_request(self):
        self.connection.settimeout(15)
        try:self.route()
        except (ValueError,KeyError,TypeError,OverflowError):self.reply(400,{'error':'数据无效或超过限制'})
        except Exception:self.reply(500,{'error':'服务暂不可用，原数据保留'})
    do_GET=handle_request;do_POST=handle_request;do_PUT=handle_request

def serve(host,port,directory):
    server=ThreadingHTTPServer((host,port),Handler);server.hub=Hub(directory);return server
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--host',default='127.0.0.1');parser.add_argument('--port',type=int,default=8788);parser.add_argument('--data',default='data/community');args=parser.parse_args()
    server=serve(args.host,args.port,args.data)
    print('MoJian hub ready. Credentials are in the private data directory. Remote use requires HTTPS.')
    try:server.serve_forever()
    except KeyboardInterrupt:server.server_close()
