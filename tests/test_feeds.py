import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from feeds import normalize_codes,parse_quotes,weather_text
class FeedTests(unittest.TestCase):
 def test_validation(self):
  self.assertEqual(normalize_codes(['SHA600519'.replace('SHA','SH'),'usaapl']),['sh600519','usAAPL'])
  for values in [['sh600519']*2,['sh000001']*6,['sh600519&x=1'],['bad'],[123]]:
   with self.assertRaises(ValueError):normalize_codes(values)
 def test_parser(self):
  fields=['']*33;fields[1]='测试股票';fields[3]='10.50';fields[30]='20261016150000';fields[31]='-0.50';fields[32]='-4.55'
  text='v_sh600001="'+'~'.join(fields)+'";v_bad="1";'
  result=parse_quotes(text)['sh600001'];self.assertEqual(result['change'],-.5);self.assertEqual(result['percent'],-4.55)
  self.assertEqual(parse_quotes('v_sh600001="1";'),{})
 def test_weather(self):self.assertEqual(weather_text(3),'阴');self.assertEqual(weather_text(95),'雷雨')
 def test_three_day_forecast_and_failure_preserves_cache(self):
  import tempfile,json
  from unittest.mock import patch
  from feeds import Feeds
  data={'current':{'temperature_2m':22,'weather_code':2,'time':'2026-10-16T21:00'},'daily':{'time':['2026-10-16','2026-10-17','2026-10-18'],'temperature_2m_max':[24,25,24],'temperature_2m_min':[19,18,18],'weather_code':[2,61,0]}}
  with tempfile.TemporaryDirectory() as folder:
   feed=Feeds(lambda:{'stocks':[]},Path(folder)/'feeds.json')
   with patch.object(feed,'fetch',return_value=json.dumps(data)) as fetch:feed.update()
   self.assertIn('forecast_days=3',fetch.call_args.args[0])
   self.assertEqual(len(feed.snapshot()['weather']['forecast']),3)
   self.assertEqual(feed.snapshot()['weather']['forecast'][1]['code'],61)
   before=feed.snapshot()['weather']
   with feed.lock:feed.cache['weather_checked']=0
   with patch.object(feed,'fetch',side_effect=OSError):feed.update()
   self.assertEqual(feed.snapshot()['weather'],before);self.assertTrue(feed.snapshot()['weather_error'])
