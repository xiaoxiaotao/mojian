import sys,json,threading,unittest,urllib.request
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
import app
class DisplayControlTest(unittest.TestCase):
 def test_one_shot_refresh_keeps_pause(self):
  old=app.TOKEN;app.TOKEN='test-display-only'
  with app.connect() as db:
   db.execute('INSERT OR REPLACE INTO display_control VALUES(1,1)');db.execute('DELETE FROM display_request')
  server=app.ThreadingHTTPServer(('127.0.0.1',0),app.Handler)
  thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
  def call(path,data=None):
   req=urllib.request.Request(f'http://127.0.0.1:{server.server_port}'+path,data=json.dumps(data).encode() if data is not None else None,headers={'Authorization':'Bearer test-display-only','Content-Type':'application/json'})
   with urllib.request.urlopen(req) as r:return r.status,r.read()
  try:
   self.assertEqual(call('/api/device/state'),(204,b''))
   self.assertTrue(json.loads(call('/api/display/refresh',{})[1])['queued'])
   status,raw=call('/api/device/state');state=json.loads(raw);self.assertEqual(status,200);self.assertTrue(state['full_request'])
   call('/api/device/ack',{'revision':state['revision'],'full_request':'wrong-nonce'});self.assertTrue(app.full_request())
   call('/api/device/ack',{'revision':state['revision'],'full_request':state['full_request']})
   self.assertEqual(call('/api/device/state'),(204,b''));self.assertTrue(app.screen_paused())
  finally:server.shutdown();server.server_close();thread.join();app.TOKEN=old
