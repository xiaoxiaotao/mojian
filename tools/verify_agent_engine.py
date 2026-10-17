"""Real Harness + model integration against isolated mock product tools.
No production task, reminder, memory, or device is changed. Use --live explicitly.
"""
from pathlib import Path
import json,subprocess,sys,tempfile,selectors,time,os
root=Path(__file__).resolve().parents[1]
engine=root/'agent-engine'
if '--live' not in sys.argv:
    raise SystemExit('Pass --live to exercise the real model with isolated fixture tools.')
env={}
for line in (root/'.env').read_text().splitlines():
    if '=' in line and not line.startswith('#'):
        k,v=line.split('=',1);env[k]=v.strip().strip('"\'')
with tempfile.TemporaryDirectory(prefix='agent-test-',dir=root/'data') as home:
    stderr=open(Path(home)/'stderr.log','w')
    p=subprocess.Popen([str(engine/'runtime/bin/node'),str(engine/'bridge.mjs')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=stderr,text=True,bufsize=1,env={'HOME':os.environ['HOME'],'PATH':'/usr/bin:/bin'})
    def write(x):p.stdin.write(json.dumps(x,ensure_ascii=False)+'\n');p.stdin.flush()
    selector=selectors.DefaultSelector();selector.register(p.stdout,selectors.EVENT_READ)
    calls=[]
    def run(prompt,session=None):
        write(dict(type='run',id='test',prompt=prompt,key=env['DEEPSEEK_API_KEY'],model=env.get('DEEPSEEK_MODEL','deepseek-flash'),context={'fixture':True,'city':'苏州'},home=home,session=session,automatic=False))
        deadline=time.monotonic()+150
        while time.monotonic()<deadline:
            if not selector.select(1):
                if p.poll() is not None:raise RuntimeError('Agent process exited')
                continue
            line=p.stdout.readline()
            if not line:raise RuntimeError('Agent output closed')
            value=json.loads(line)
            if value['type']=='tool':
                name=value['name'];calls.append(name)
                if name=='list_tasks':result={'tasks':[]}
                elif name=='get_commute':result={'source':'高德（测试夹具，非真实路况）','minutes':12,'traffic':'畅通','fixture':True}
                elif name=='set_commute_reminder':result={'status':'pending_confirmation','summary':'开启通勤提醒（仅测试夹具，未保存）'}
                elif name=='get_context':result={'fixture':True,'time':'2026-10-17 09:00','city':'苏州'}
                else:result={'error':'测试不开放此操作'}
                write({'type':'tool_result','id':value['id'],'result':result})
            elif value['type']=='error':raise RuntimeError(value['message'])
            elif value['type']=='done':return value
        raise TimeoutError('Agent did not finish')
    try:
        first=run('这是隔离测试。请先调用list_tasks，再调用get_commute，最后调用set_commute_reminder提出开启提醒。所有写操作待确认，不能声称已开启。请用一句话说明结果。')
        assert {'list_tasks','get_commute','set_commute_reminder'}.issubset(calls),calls
        assert first['session'] and first['text']
        p.stdin.close();p.wait(timeout=15);selector.close()
        p=subprocess.Popen([str(engine/'runtime/bin/node'),str(engine/'bridge.mjs')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=stderr,text=True,bufsize=1,env={'HOME':os.environ['HOME'],'PATH':'/usr/bin:/bin'})
        selector=selectors.DefaultSelector();selector.register(p.stdout,selectors.EVENT_READ)
        second=run('刚才的通勤提醒是否已经开启？只根据上一轮实际工具结果回答，不调用工具。',first['session'])
        assert second['session']==first['session']
        print(json.dumps({'engine':'DeepSeek Harness 0.2.1-alpha.5','tools':calls,'first_response':first['text'],'second_response':second['text'],'session_restored_after_process_restart':True,'production_changes':False},ensure_ascii=False))
    except Exception:
        stderr.flush()
        # Diagnostics stay in the isolated folder, never dump requests, env or keys.
        if os.environ.get('MOJIAN_AGENT_DIAGNOSTICS')=='1':print(Path(home,'stderr.log').read_text()[-5000:])
        raise
    finally:
        p.stdin.close()
        try:p.wait(timeout=12)
        except subprocess.TimeoutExpired:p.terminate();p.wait(timeout=8)
        stderr.close()
