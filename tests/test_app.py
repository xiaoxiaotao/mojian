import os, tempfile, unittest, sys
from pathlib import Path
os.environ['TODO_DATA_DIR']=tempfile.mkdtemp(prefix='desk-todo-test-')
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
import app
from datetime import timedelta
class TodoTests(unittest.TestCase):
 def setUp(self):
  with app.connect() as db: db.execute('DELETE FROM tasks')
 def test_complete_removes_and_restore_returns(self):
  task=app.create_task('交方案', (app.now()-timedelta(minutes=1)).isoformat())
  before=app.render()[0];self.assertTrue(app.overdue(app.tasks()[0]));self.assertEqual(len(before),96000)
  self.assertNotEqual(before[48000:],bytes([255])*48000)
  app.complete(task);after=app.render()[0];self.assertEqual(after[48000:],bytes([255])*48000)
  app.complete(task,False);self.assertEqual(app.render()[0],before)
 def test_deadline_and_no_due(self):
  app.create_task('无期限');self.assertFalse(app.overdue(app.tasks()[0]))
  app.create_task('未来',(app.now()+timedelta(days=1)).isoformat());self.assertTrue(all(not app.overdue(t) for t in app.tasks()))
 def test_bad_input(self):
  with self.assertRaises(ValueError): app.create_task(' ')
  with self.assertRaises(ValueError): app.create_task('测试','not-a-date')
  with self.assertRaises(ValueError): app.complete('missing')
 def test_revision_changes_at_deadline(self):
  task={'due':'2026-10-16T12:00:00+08:00'}
  from datetime import datetime
  self.assertFalse(app.overdue(task,datetime.fromisoformat('2026-10-16T11:59:59+08:00')))
  self.assertTrue(app.overdue(task,datetime.fromisoformat('2026-10-16T12:00:00+08:00')))
if __name__=='__main__':unittest.main()

class AgentToolTests(unittest.TestCase):
 def test_model_tool_roundtrip(self):
  from unittest.mock import patch
  import io,json
  def response(message): return io.BytesIO(json.dumps({'choices':[{'message':message}]}).encode())
  replies=[response({'role':'assistant','content':None,'tool_calls':[{'id':'call1','type':'function','function':{'name':'add_task','arguments':json.dumps({'title':'模拟 Agent 任务'})}}]}),response({'role':'assistant','content':'已添加任务。'})]
  with patch.dict(os.environ,{'DEEPSEEK_API_KEY':'test-only'}),patch('urllib.request.urlopen',side_effect=replies) as network:
   self.assertEqual(app.chat([{'role':'user','content':'添加模拟 Agent 任务'}]),'已添加任务。')
   sent=json.loads(network.call_args_list[1].args[0].data)
   self.assertEqual(sent['messages'][-1]['role'],'tool')
   self.assertTrue(any(t['title']=='模拟 Agent 任务' for t in app.tasks()))
