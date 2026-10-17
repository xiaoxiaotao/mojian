"""Office layout A. Every dynamic cell is clipped to its firmware refresh region."""
import math, os
from datetime import datetime
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
REGIONS = {
 'clock':(24,0,208,64), 'date':(24,64,208,40),
 'weather':(264,8,240,88), 'next_task':(528,8,248,88),
 'stock_heading':(24,112,480,64), 'todo_heading':(536,112,240,40),
 **{f'stock_{i}':(24,184+i*44,480,44) for i in range(5)},
 **{f'todo_{i}':(536,160+i*58,240,56) for i in range(4)},
 **{f'forecast_{i}':(24+i*168,432,160,24) for i in range(3)},
 'task_summary':(528,432,248,32),
}
def font(n, numeric=False):
 path='/System/Library/Fonts/Supplemental/Arial Bold.ttf' if numeric else os.environ.get('TODO_FONT','/System/Library/Fonts/STHeiti Medium.ttc')
 return ImageFont.truetype(path,n)
def text(d,x,y,value,n=18,right=False,width=None,numeric=False):
 value=str(value);f=font(n,numeric)
 if width and f.getlength(value)>width:
  while value and f.getlength(value+'…')>width:value=value[:-1]
  value+='…'
 if right:x-=d.textlength(value,font=f)
 d.text((x,y),value,font=f,fill=0)
def icon(d,x,y,code,scale=1):
 # Simple line icons remain legible without grey dithering.
 if code in (0,1,2):
  cx,cy=x+12*scale,y+8*scale;r=7*scale
  d.ellipse((cx-r,cy-r,cx+r,cy+r),outline=0,width=1)
  for a in range(0,360,60):
   c,s=math.cos(math.radians(a)),math.sin(math.radians(a));d.line((cx+c*10*scale,cy+s*10*scale,cx+c*14*scale,cy+s*14*scale),fill=0)
 if code!=0:
  for box in [(3,13,24,29),(14,6,39,30),(31,15,48,29)]:
   d.ellipse(tuple((x if i%2==0 else y)+v*scale for i,v in enumerate(box)),fill=1,outline=0)
  d.rectangle((x+9*scale,y+20*scale,x+40*scale,y+30*scale),fill=1)
  d.line((x+8*scale,y+30*scale,x+41*scale,y+30*scale),fill=0)
  if code>=51:
   for dx in (15,27,39):d.line((x+dx*scale,y+33*scale,x+(dx-2)*scale,y+38*scale),fill=0)
def due_label(task,stamp):
 if not task.get('due'):return '未设截止时间'
 due=datetime.fromisoformat(task['due']);days=(due.date()-stamp.date()).days
 day='今天' if days==0 else '明天' if days==1 else due.strftime('%m/%d')
 return ('已逾期 · ' if due<=stamp else '')+day+' '+due.strftime('%H:%M')
def draw(active,config,cache,stamp):
 bw=Image.new('1',(800,480),1);red=Image.new('1',(800,480),1);b=ImageDraw.Draw(bw)
 # Static rules never move when the values change.
 for coords,w in [((248,18,248,92),1),((512,18,512,92),1),((24,108,776,108),2),((520,120,520,405),1),((24,176,504,176),1),((24,424,776,424),1)]:b.line(coords,fill=0,width=w)
 def cell(name,paint):
  x,y,w,h=REGIONS[name];im=Image.new('1',(w,h),1);ri=Image.new('1',(w,h),1)
  paint(ImageDraw.Draw(im),ImageDraw.Draw(ri));bw.paste(im,(x,y));red.paste(ri,(x,y))
 cell('clock',lambda d,r:text(d,0,6,stamp.strftime('%H:%M'),56,numeric=True))
 cell('date',lambda d,r:text(d,2,8,stamp.strftime('%m月%d日')+' 星期'+'一二三四五六日'[stamp.weekday()],18))
 weather=cache.get('weather') or {}
 def current(d,r):
  if not weather:text(d,8,24,'苏州 · 天气待更新',20);return
  icon(d,4,25,weather.get('code',3),1.05)
  text(d,70,10,'苏州 · '+weather['text'],20,width=168)
  text(d,70,37,f"{weather['temperature']:.0f}°",38,numeric=True)
  text(d,160,50,f"{weather['low']:.0f}°/{weather['high']:.0f}°",16)
  text(d,70,78,'更新异常，保留旧值' if cache.get('weather_error') else '天气 '+weather.get('as_of','')[11:16],10)
 cell('weather',current)
 upcoming=sorted((t for t in active if t.get('due') and datetime.fromisoformat(t['due'])>stamp),key=lambda t:t['due'])
 focus=upcoming[0] if upcoming else (active[0] if active else None)
 def next_task(d,r):
  text(d,8,8,'接下来' if upcoming else '待办提醒',15)
  text(d,8,35,focus['title'] if focus else '今日待办已清空',21,width=232)
  text(d,8,68,due_label(focus,stamp) if focus else '安心专注，随时添加',16,width=232)
 cell('next_task',next_task)
 quotes=cache.get('quotes',{});codes=config.get('stocks',[])[:5]
 observations=[str(quotes[c].get('as_of','')) for c in codes if c in quotes]
 oldest=min(observations) if observations else ''
 asof=oldest[4:6]+'/'+oldest[6:8]+' '+oldest[8:10]+':'+oldest[10:12] if len(oldest)==14 and oldest.isdigit() else oldest[:16]
 def heading(d,r):
  text(d,0,9,'自选行情',23)
  text(d,480,13,('更新异常 · ' if cache.get('quote_error') else '')+(asof or '等待行情'),12,right=True,width=280)
  text(d,0,45,'股票 / 代码',14);text(d,296,45,'最新价',14,right=True);text(d,480,45,'涨跌幅 / 涨跌额',14,right=True)
 cell('stock_heading',heading)
 for i in range(5):
  def stock(d,r,i=i):
   if i>=len(codes):text(d,0,5,'— 网页端添加股票',18)
   else:
    code=codes[i];q=quotes.get(code)
    if not q:text(d,0,5,code+' 暂无行情',18,width=470)
    else:
     text(d,0,0,q['name'],21,width=148);text(d,0,26,code,12)
     if q['change']:
      x,y,size=160,6,12
      d.polygon([(x+size/2,y),(x,y+size),(x+size,y+size)] if q['change']>0 else [(x,y),(x+size,y),(x+size/2,y+size)],fill=0)
     else:text(d,160,0,'—',17)
     text(d,296,0,f"{q['price']:.2f}",24,right=True,numeric=True)
     text(d,480,0,f"{q['percent']:+.2f}%",21,right=True,numeric=True)
     text(d,480,26,f"{q['change']:+.2f}",14,right=True)
   if i<4:d.line((0,40,479,40),fill=0)
  cell('stock_'+str(i),stock)
 def todo_heading(d,r):
  text(d,0,9,'待办清单',23);text(d,240,14,f'{len(active):02d} 项',16,right=True)
 cell('todo_heading',todo_heading)
 for i in range(4):
  def task_row(d,r,i=i):
   if i>=len(active):
    if i==0:text(d,2,8,'暂无待办',19)
    return
   task=active[i];d.rectangle((1,9,11,19),outline=0,width=2)
   late=bool(task.get('due') and datetime.fromisoformat(task['due'])<=stamp)
   text(d,22,4,task['title'],18,width=198 if late else 216)
   text(d,22,31,due_label(task,stamp),13,width=216)
   if late:r.rectangle((229,10,237,18),fill=0)
  cell('todo_'+str(i),task_row)
 forecast=weather.get('forecast',[])
 for i in range(3):
  def day(d,r,i=i):
   if i>=len(forecast):text(d,0,4,['今天','明天','后天'][i]+' 预报待更新',14);return
   item=forecast[i];date=datetime.fromisoformat(item['date']).date();offset=(date-stamp.date()).days
   label={0:'今天',1:'明天',2:'后天'}.get(offset,date.strftime('%m/%d'))
   text(d,0,6,label,15);icon(d,38,0,item.get('code',3),.48)
   text(d,80,5,f"{item['low']:.0f}°/{item['high']:.0f}°",16)
  cell('forecast_'+str(i),day)
 def summary(d,r):
  late=sum(bool(t.get('due') and datetime.fromisoformat(t['due'])<=stamp) for t in active)
  text(d,8,4,f'{len(active)} 项待办 · {late} 项逾期',16,width=240)
  if len(active)>4:text(d,8,22,f'另有 {len(active)-4} 条见网页',9)
 cell('task_summary',summary)
 text(b,24,465,'行情：腾讯（可能延迟） · 天气：Open-Meteo',10)
 return bw,red
