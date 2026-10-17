"""Prototype public data adapters. Network access runs outside rendering requests."""
import json,re,threading,time,urllib.request,math
from datetime import datetime
from zoneinfo import ZoneInfo
TZ=ZoneInfo('Asia/Shanghai')
CODE=re.compile(r'(?:sh\d{6}|sz\d{6}|bj\d{6}|hk\d{5}|us[A-Z][A-Z0-9.]{0,9})\Z')
def normalize_codes(values):
    if not isinstance(values,list) or len(values)>5: raise ValueError('最多配置 5 支股票')
    out=[]
    for value in values:
        if not isinstance(value,str):raise ValueError('股票代码格式不正确')
        value=value.strip()
        value=value[:2].lower()+(value[2:].upper() if value[:2].lower()=='us' else value[2:])
        if not CODE.fullmatch(value):raise ValueError('代码示例：sh600519、sz000001、hk00700、usAAPL')
        if value in out:raise ValueError('股票代码不能重复')
        out.append(value)
    return out

def parse_quotes(text):
    quotes={}
    for code,payload in re.findall(r'v_(\w+)="([^"]*)"',text):
        fields=payload.split('~')
        if len(fields)<33:continue
        try:
            price,change,percent=map(float,(fields[3],fields[31],fields[32]))
            if not all(math.isfinite(v) for v in (price,change,percent)) or price<=0:continue
        except ValueError:continue
        quotes[code]={'code':code,'name':fields[1],'price':price,'change':change,'percent':percent,'as_of':fields[30]}
    return quotes

def weather_text(code):
    if code==0:return '晴'
    if code in (1,2):return '多云'
    if code==3:return '阴'
    if code in (45,48):return '雾'
    if code in (51,53,55,56,57):return '毛毛雨'
    if code in (61,63,65,66,67,80,81,82):return '雨'
    if code in (71,73,75,77,85,86):return '雪'
    if code in (95,96,99):return '雷雨'
    return '天气未知'

class Feeds:
    def __init__(self,settings,path):
        self.settings=settings;self.path=path;self.lock=threading.Lock();self.wake=threading.Event()
        try:self.cache=json.loads(path.read_text())
        except (OSError,ValueError):self.cache={}
    def snapshot(self):
        with self.lock:return json.loads(json.dumps(self.cache))
    def fetch(self,url,encoding='utf-8'):
        req=urllib.request.Request(url,headers={'User-Agent':'DeskDashboard/0.2'})
        with urllib.request.urlopen(req,timeout=12) as response:return response.read().decode(encoding)
    def update(self):
        codes=self.settings()['stocks'];stamp=datetime.now(TZ).isoformat(timespec='seconds')
        updates={}
        if codes:
            try:
                quotes=parse_quotes(self.fetch('https://qt.gtimg.cn/q='+','.join(codes),'gb18030'))
                # Keep last successful quote when one symbol is temporarily missing.
                previous=self.snapshot().get('quotes',{})
                quotes={c:dict(q,received_at=stamp) for c,q in quotes.items() if c in codes}
                missing=[c for c in codes if c not in quotes]
                updates.update(quotes={**{c:q for c,q in previous.items() if c in codes},**quotes},quote_error=bool(missing))
            except Exception:updates['quote_error']=True
        else:updates.update(quotes={},quote_error=False)
        old=self.snapshot()
        if time.time()-old.get('weather_checked',0)>=(60 if old.get('weather_error') else 1800) or not old.get('weather',{}).get('forecast'):
            try:
                data=json.loads(self.fetch('https://api.open-meteo.com/v1/forecast?latitude=31.30&longitude=120.58&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=Asia%2FShanghai&forecast_days=3'))
                current=data['current'];daily=data['daily']
                updates.update(weather={'temperature':current['temperature_2m'],'text':weather_text(current['weather_code']),'high':daily['temperature_2m_max'][0],'low':daily['temperature_2m_min'][0],'as_of':current['time'],'code':current['weather_code'],'forecast':[{'date':day,'high':daily['temperature_2m_max'][i],'low':daily['temperature_2m_min'][i],'code':daily['weather_code'][i]} for i,day in enumerate(daily['time'])]},weather_checked=time.time(),weather_error=False)
            except Exception as error:updates.update(weather_error=True,weather_error_kind=type(error).__name__,weather_checked=time.time())
        with self.lock:
            self.cache.update(updates)
            temp=self.path.with_suffix('.tmp');temp.write_text(json.dumps(self.cache,ensure_ascii=False));temp.replace(self.path)
    def run(self):
        while True:
            self.wake.clear()
            try:self.update()
            except Exception:pass
            self.wake.wait(60 if self.snapshot().get('weather_error') or self.snapshot().get('quote_error') else 600)
    def start(self):threading.Thread(target=self.run,daemon=True,name='dashboard-feeds').start()
