"""Standalone 800x480 monochrome layout studies; no service/device/data mutations.
All displayed content is illustrative, not a live stock/weather screen.
"""
from pathlib import Path
import math
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/layout-research-2026-10-16';OUT.mkdir(parents=True,exist_ok=True)
CJK='/System/Library/Fonts/STHeiti Medium.ttc'
LAT='/System/Library/Fonts/Supplemental/Arial.ttf'
BOLD='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
S=[('中粮糖业','600737','14.05','+4.77%','+0.64',1),('牧原股份','002714','41.10','+3.40%','+1.35',1),('瑞芯微','603893','171.01','−9.99%','−18.99',-1),('水晶光电','002273','19.40','−0.61%','−0.12',-1),('天岳先进','688234','86.13','−0.69%','−0.60',-1)]
TASKS=[('提交今日工作小结','今天 21:30 · 还有32分钟'),('整理下周会议材料','明天 15:00'),('发送客户确认邮件','明天 16:30'),('核对本月报销清单','未设截止时间')]
REGIONS={}
def font(n,numeric=False,bold=False):return ImageFont.truetype(BOLD if numeric and bold else LAT if numeric else CJK,n)
def text(d,xy,s,n=20,numeric=False,bold=False,right=False,maxw=None):
 f=font(n,numeric,bold)
 if maxw:
  while f.getlength(s)>maxw:s=s[:-2]+'…'
 x,y=xy
 if right:x-=d.textlength(s,font=f)
 d.text((x,y),s,font=f,fill=0,stroke_width=0)
def line(d,xy,w=1):d.line(xy,fill=0,width=w)
def cloud(d,x,y,scale=1,sun=False):
 if sun:
  cx,cy=x+12*scale,y+8*scale;r=7*scale
  d.ellipse((cx-r,cy-r,cx+r,cy+r),outline=0,width=2)
  for a in range(0,360,60):
   c,s=math.cos(math.radians(a)),math.sin(math.radians(a));line(d,(cx+c*10*scale,cy+s*10*scale,cx+c*14*scale,cy+s*14*scale),2)
 for box in [(x+3*scale,y+13*scale,x+24*scale,y+29*scale),(x+14*scale,y+6*scale,x+39*scale,y+30*scale),(x+31*scale,y+15*scale,x+48*scale,y+29*scale)]:d.ellipse(box,fill=1,outline=0,width=2)
 d.rectangle((x+9*scale,y+20*scale,x+40*scale,y+30*scale),fill=1)
 line(d,(x+8*scale,y+30*scale,x+41*scale,y+30*scale),2)
def arrow(d,x,y,up,size=13):
 pts=[(x+size/2,y),(x,y+size),(x+size,y+size)] if up else [(x,y),(x+size,y),(x+size/2,y+size)]
 d.polygon(pts,fill=0)
def base():return Image.new('1',(800,480),1)
def caption(d):text(d,(400,465),'布局研究稿 · 示例数据，非实时行情 / 天气',11,right=False)
# Caption centered separately, no live service labels.
def finish(im,name,regions):
 d=ImageDraw.Draw(im);f=font(11);label='布局研究稿 · 示例数据，非实时行情 / 天气';d.text(((800-d.textlength(label,font=f))/2,465),label,font=f,fill=0)
 im.save(OUT/(name+'.png'))
 overlay=im.convert('RGB');od=ImageDraw.Draw(overlay)
 for i,(label,(x,y,w,h)) in enumerate(regions.items()):
  assert x % 8 == 0 and w % 8 == 0, (label, x, w)
  assert 0 <= x < x+w <= 800 and 0 <= y < y+h <= 480, label
  od.rectangle((x,y,x+w-1,y+h-1),outline='#cc3322',width=1)
  od.text((x+2,y+2),str(i+1),font=font(10,True),fill='#cc3322')
 overlay.save(OUT/(name+'-regions.png'))
 REGIONS[name]=regions

def office():
 im=base();d=ImageDraw.Draw(im)
 text(d,(24,6),'20:58',56,True,True)
 text(d,(26,72),'10月16日  星期五',18)
 line(d,(248,18,248,92));line(d,(512,18,512,92))
 cloud(d,268,33,1.05,True)
 text(d,(334,18),'苏州 · 多云',20,bold=True)
 text(d,(334,45),'22°',38,True,True)
 text(d,(424,58),'19° / 24°',18,True)
 text(d,(536,16),'接下来',15)
 text(d,(536,43),'提交今日工作小结',21,bold=True,maxw=236)
 text(d,(536,76),'21:30 · 还有32分钟',17)
 line(d,(24,108,776,108),2)
 text(d,(24,121),'自选行情',23,bold=True)
 text(d,(504,125),'行情截至 15:00',14,right=True)
 text(d,(24,157),'股票 / 代码',14);text(d,(320,157),'最新价',14,right=True);text(d,(504,157),'涨跌幅 / 涨跌额',14,right=True)
 line(d,(24,176,504,176));line(d,(520,120,520,405))
 regions={'clock':(24,0,208,64),'date':(24,64,208,40),'weather':(264,8,240,88),'next_task':(528,8,248,88)}
 for i,(name,code,price,pct,delta,up) in enumerate(S):
  y=185+i*44
  text(d,(24,y-1),name,21,bold=True);text(d,(24,y+25),code,12,True)
  arrow(d,184,y+5,up>0,12)
  text(d,(320,y-1),price,24,True,True,right=True)
  text(d,(504,y-1),pct,21,True,True,right=True)
  text(d,(504,y+25),delta,14,True,right=True)
  if i<4:line(d,(24,y+39,504,y+39))
  regions['stock_'+str(i+1)]=(24,184+i*44,480,44)
 text(d,(536,121),'待办清单',23,bold=True);text(d,(776,126),'04 项',16,right=True)
 for i,(title,due) in enumerate(TASKS):
  y=164+i*58
  d.rectangle((537,y+5,547,y+15),outline=0,width=2)
  text(d,(558,y),title,18,maxw=216,bold=True);text(d,(558,y+27),due,14,maxw=216)
  regions['todo_'+str(i+1)]=(536,160+i*58,240,56)
 line(d,(24,424,776,424))
 for i,(name,temps,sun) in enumerate([('今天','19° / 24°',True),('明天','18° / 25°',False),('后天','18° / 24°',True)]):
  x=24+i*168;text(d,(x,438),name,15);cloud(d,x+38,432,.48,sun);text(d,(x+80,437),temps,16,True)
  regions['forecast_'+str(i)]=(24+i*168,432,160,24)
 text(d,(536,436),'4 项待办 · 0 项逾期',17)
 regions['stock_heading']=(24,112,480,64)
 regions['todo_heading']=(536,112,240,40)
 regions['task_summary']=(528,432,248,24)
 finish(im,'layout-a-office',regions)

def market():
 im=base();d=ImageDraw.Draw(im)
 text(d,(24,9),'20:58',53,True,True);text(d,(229,20),'10月16日  星期五',20,bold=True);text(d,(229,55),'办公信息中心',16)
 cloud(d,535,24,.9,True);text(d,(590,19),'苏州 22°',29,bold=True);text(d,(590,58),'多云 · 19° / 24°',16)
 line(d,(24,96,776,96),2)
 text(d,(24,109),'自选行情',22,bold=True);text(d,(776,114),'截至 15:00',14,right=True)
 regions={'clock':(24,0,200,80),'date':(224,8,280,72),'weather':(528,8,248,80)}
 for i,(name,code,price,pct,delta,up) in enumerate(S):
  x=24+i*152
  if i:line(d,(x-12,149,x-12,281))
  text(d,(x,151),name,20,bold=True,maxw=136);text(d,(x,181),code,13,True)
  text(d,(x,207),price,30,True,True)
  arrow(d,x,251,up>0,13);text(d,(x+23,246),pct,19,True,True)
  text(d,(x,276),delta,14,True)
  regions['stock_'+str(i+1)]=(24+i*152,144,152,152)
 line(d,(24,309,776,309),2)
 text(d,(24,324),'待办清单',22,bold=True);text(d,(496,329),'03 项',15,right=True)
 line(d,(520,324,520,446))
 for i,(title,due) in enumerate(TASKS[:3]):
  y=365+i*32;d.rectangle((25,y+4,35,y+14),outline=0,width=2);text(d,(48,y),title,18,bold=True,maxw=244)
  due=['今天 21:30','明天 15:00','明天 16:30'][i];text(d,(496,y+1),due,15,right=True)
  regions['todo_'+str(i+1)]=(24,360+i*32,480,32)
 text(d,(536,324),'三日天气',22,bold=True)
 for i,(day,temps,sun) in enumerate([('今天','19° / 24°',True),('明天','18° / 25°',False),('后天','18° / 24°',True)]):
  y=363+i*32;text(d,(536,y),day,16);cloud(d,582,y-2,.46,sun);text(d,(776,y),temps,18,True,right=True)
  regions['forecast_'+str(i)]=(536,360+i*32,240,32)
 regions['stock_heading']=(24,104,752,32)
 regions['todo_heading']=(24,320,480,32)
 regions['forecast_heading']=(536,320,240,32)
 finish(im,'layout-b-market',regions)

office();market()
(OUT/'proposed-regions.json').write_text(__import__('json').dumps(REGIONS,ensure_ascii=False,indent=2))
print('Generated two 800x480 studies and region overlays. Live screen unchanged.')
