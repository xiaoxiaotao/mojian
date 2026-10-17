import sys,unittest,json
from pathlib import Path
from unittest.mock import patch
from datetime import datetime
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
import app
class LayoutTests(unittest.TestCase):
 def test_stock_sign_changes_keep_red_plane_white(self):
  quote={'name':'测试股票','price':100.0,'change':1.0,'percent':1.0,'as_of':'20261016150000'}
  config={'stocks':['sh600000']}
  with patch.object(app,'settings',return_value=config),patch.object(app,'tasks',return_value=[]),patch.object(app,'now',return_value=datetime.fromisoformat('2026-10-16T20:01:00+08:00')):
   with patch.object(app.feeds,'snapshot',return_value={'quotes':{'sh600000':quote}}):first=app.render()[0]
   with patch.object(app.feeds,'snapshot',return_value={'quotes':{'sh600000':dict(quote,price=99.0,change=-1.0,percent=-1.0)}}):second=app.render()[0]
   self.assertEqual(first[48000:],second[48000:]);self.assertNotEqual(first[:48000],second[:48000])
   self.assertEqual(first[48000:],bytes([255])*48000)
 def test_minute_changes_only_clock_region(self):
  with patch.object(app,'settings',return_value={'stocks':[]}),patch.object(app,'tasks',return_value=[]),patch.object(app.feeds,'snapshot',return_value={}):
   with patch.object(app,'now',return_value=datetime.fromisoformat('2026-10-16T20:01:00+08:00')):first=app.render()[0]
   with patch.object(app,'now',return_value=datetime.fromisoformat('2026-10-16T20:02:00+08:00')):second=app.render()[0]
   diff=[i for i in range(48000) if first[i]!=second[i]];self.assertTrue(diff)
   for i in diff:self.assertTrue(3<=i%100<29 and 0<=i//100<64)
 def test_regions_match_firmware_and_do_not_overlap(self):
  from dashboard import REGIONS
  regions=list(REGIONS.values())
  self.assertEqual([list(r) for r in regions],json.loads((app.ROOT/'config/refresh_regions.json').read_text()))
  for i,(x,y,w,h) in enumerate(regions):
   self.assertEqual(x%8,0);self.assertEqual(w%8,0)
   for xx,yy,ww,hh in regions[i+1:]:self.assertTrue(x+w<=xx or xx+ww<=x or y+h<=yy or yy+hh<=y)
 def test_fourth_todo_is_rendered_and_completed_disappears(self):
  from dashboard import draw,REGIONS
  at=datetime.fromisoformat('2026-10-16T20:01:00+08:00')
  entries=[{'title':str(i)+' 第四条也应显示','due':None} for i in range(4)]
  before=draw(entries,{'stocks':[]},{},at)[0]
  after=draw(entries[:3],{'stocks':[]},{},at)[0]
  x,y,w,h=REGIONS['todo_3']
  self.assertNotEqual(before.crop((x,y,x+w,y+h)).tobytes(),after.crop((x,y,x+w,y+h)).tobytes())
  self.assertIsNone(after.crop((x,y,x+w,y+h)).convert('L').point(lambda v:255-v).getbbox())
 def test_long_task_changes_stay_within_task_regions(self):
  from dashboard import draw,REGIONS
  at=datetime.fromisoformat('2026-10-16T20:01:00+08:00')
  entries=[{'title':'很长的中文待办标题'*12,'due':None} for i in range(5)]
  before=draw(entries,{'stocks':[]},{},at)[0].tobytes()
  after=draw(entries[1:],{'stocks':[]},{},at)[0].tobytes()
  changed=[i for i in range(48000) if before[i]!=after[i]]
  self.assertTrue(changed)
  allowed=[REGIONS[n] for n in ('todo_heading','task_summary')]
  for i in changed:self.assertTrue(any(x//8<=i%100<(x+w)//8 and y<=i//100<y+h for x,y,w,h in allowed))
