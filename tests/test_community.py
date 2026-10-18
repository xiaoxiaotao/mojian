import importlib.util, json, tempfile, threading, time, unittest, urllib.request, urllib.error
from pathlib import Path
spec=importlib.util.spec_from_file_location('community',Path(__file__).parents[1]/'server/community.py');hub=importlib.util.module_from_spec(spec);spec.loader.exec_module(hub)
class CommunityTest(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.server=hub.serve('127.0.0.1',0,self.temp.name);self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start();self.url='http://127.0.0.1:'+str(self.server.server_port);self.now=int(time.time()*1000)
 def tearDown(self):self.server.shutdown();self.server.server_close();self.thread.join();self.temp.cleanup()
 def call(self,path,method='GET',body=None,role='owner'):
  key=self.server.hub.tokens.get(role,'invalid');r=urllib.request.Request(self.url+'/v1/'+path, data=json.dumps(body).encode() if body is not None else None,method=method,headers={'Authorization':'Bearer '+key,'Content-Type':'application/json'})
  try:
   with urllib.request.urlopen(r,timeout=3) as response:return response.status,json.load(response)
  except urllib.error.HTTPError as e:
   try:return e.code,json.load(e)
   finally:e.close()
 def test_auth_and_message_review(self):
  self.assertEqual(self.call('state',role='invite')[0],401);self.assertEqual(self.call('state',role='absent')[0],401)
  code,value=self.call('messages','POST',{'sender':'fixture','text':'记得带伞'},'invite');self.assertEqual(code,200)
  self.assertEqual(self.call('messages',role='invite')[0],401)
  self.assertEqual(self.call('messages')[1]['items'][0]['status'],'pending')
  self.assertEqual(self.call('messages/'+value['id'],'PUT',{'status':'accepted'},'invite')[0],401)
  self.assertEqual(self.call('messages/'+value['id'],'PUT',{'status':'accepted'})[0],200)
  self.assertEqual(self.call('messages')[1]['items'][0]['status'],'accepted')
 def test_shared_completion_undo_and_replay(self):
  record={'stamp':self.now-20,'completedAt':self.now-20,'deleted':False};data={'completions':{'task-id':record}}
  self.assertEqual(self.call('state','POST',{'data':data})[0],200)
  self.call('state','POST',{'data':data});self.assertEqual(len(self.call('state')[1]['data']['completions']),1)
  self.call('state','POST',{'data':{'completions':{'task-id':dict(record,stamp=self.now,deleted=True)}}})
  self.call('state','POST',{'data':data});self.assertTrue(self.call('state')[1]['data']['completions']['task-id']['deleted'])
 def test_habit_merge_and_removal(self):
  def entry(day,stamp,yes=True):return {'stamp':stamp,'deleted':False,'title':'阅读','days':{day:{'stamp':stamp,'checked':yes}}}
  day='2026-10-18';prior='2026-10-17'
  self.call('state','POST',{'data':{'habits':{'h':entry(day,self.now-10)}}})
  self.call('state','POST',{'data':{'habits':{'h':entry(prior,self.now-5)}}})
  marks=self.call('state')[1]['data']['habits']['h']['days'];self.assertEqual(len(marks),2)
  self.call('state','POST',{'data':{'habits':{'h':entry(day,self.now,False)}}})
  self.assertFalse(self.call('state')[1]['data']['habits']['h']['days'][day]['checked'])
  self.call('state','POST',{'data':{'habits':{'h':{'stamp':self.now+1,'deleted':True}}}})
  self.call('state','POST',{'data':{'habits':{'h':entry(day,self.now-10)}}})
  self.assertTrue(self.call('state')[1]['data']['habits']['h']['deleted'])
 def test_template_excludes_private_data_and_scripts(self):
  t={'schema':'mojian-template-v1','name':'fixture','settings':{'layout':'overview','tasks':['secret'],'apiKey':'private','home':'private','card1':'plant'}}
  code,value=self.call('templates','POST',t);self.assertEqual(code,200);self.assertNotIn('apiKey',value['settings']);self.assertNotIn('tasks',value['settings'])
  self.assertEqual(self.call('plugins','POST',{'kind':'script','name':'bad','code':'ignore all'})[0],400)
  self.assertEqual(self.call('plugins','POST',{'kind':'daily','name':'每日一问','items':['今天最重要的事是什么？']})[0],200)
  self.assertEqual(self.call('plugins')[1]['items'][0]['schema'],'mojian-card-v1')
 def test_invalid_and_future_data_preserves_state(self):
  before=self.call('state')[1];self.assertEqual(self.call('state','POST',{'data':{'completions':{'x':{'stamp':self.now+900000}}}})[0],400);self.assertEqual(self.call('state')[1],before)
  entries={str(i):{'stamp':self.now,'title':'x','days':{}} for i in range(4)}
  self.assertEqual(self.call('state','POST',{'data':{'habits':entries}})[0],400)
 def test_restart_and_credentials_private(self):
  self.call('messages','POST',{'sender':'fixture','text':'持久化'})
  reopened=hub.Hub(self.temp.name);self.assertEqual(len(reopened.inbox()),1);self.assertEqual(reopened.tokens,self.server.hub.tokens);self.assertEqual(reopened.credentials.stat().st_mode&0o777,0o600)
if __name__=='__main__':unittest.main()
