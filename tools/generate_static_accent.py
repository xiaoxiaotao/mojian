"""Generate eight fixed red masks; styles change only during explicit full refresh."""
from pathlib import Path
from PIL import Image
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
styles=[('focus','专注办公'),('agenda','今日安排'),('minimal','极简桌面'),('overview','信息总览'),('pomodoro','专注计时'),('living','生活陪伴'),('custom','我的布局'),('calendar','下班日历')]
masks=[]
with tempfile.TemporaryDirectory(dir=root/'data') as temp:
 for name,label in styles:
    raw=Path(temp)/(name+'.png')
    subprocess.run(['swift','-sdk','/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk',str(root/'tools/generate_static_accent.swift'),str(raw),label],check=True)
    image=Image.open(raw).convert('RGB').resize((800,480),Image.Resampling.LANCZOS)
    wire=bytearray(2400);preview=Image.new('RGBA',(800,480),(255,255,255,0))
    for y in range(80,104):
        for x in range(800):
            r,g,b=image.getpixel((x,y))
            if r>g*1.4 and r>b*1.4 and g<180:
                wire[(y-80)*100+x//8]|=128>>(x%8);preview.putpixel((x,y),(192,20,26,255))
    assert sum(x.bit_count() for x in wire)>300
    preview.save(root/f'macos/Resources/StaticAccent-{name}.png');masks.append(wire)
header='''#pragma once
// Generated shared red-v2 masks. Wire bit 1 is red; all masks live in Flash.
constexpr int ACCENT_TOP=80,ACCENT_BOTTOM=104;
static const unsigned char STATIC_ACCENTS[8][2400]={
'''+',\n'.join('{\n'+',\n'.join(','.join(str(x) for x in mask[i:i+40]) for i in range(0,len(mask),40))+'\n}' for mask in masks)+'''
};
inline unsigned char staticAccentWire(unsigned i,unsigned style=0){return i>=8000&&i<10400&&style<8?STATIC_ACCENTS[style][i-8000]:0;}
inline int accentStyleIndex(const char* name){
 const char* names[]={"focus","agenda","minimal","overview","pomodoro","living","custom","calendar"};
 if(!name)return -1;
 for(int i=0;i<8;i++){const char* a=name;const char* b=names[i];while(*a&&*a==*b){a++;b++;}if(!*a&&!*b)return i;}
 return -1;
}
template<class Update> inline void withoutAccent(int x,int y,int w,int h,Update update){
 if(y<ACCENT_TOP){int bottom=y+h<ACCENT_TOP?y+h:ACCENT_TOP;update(x,y,w,bottom-y);}
 if(y+h>ACCENT_BOTTOM){int top=y>ACCENT_BOTTOM?y:ACCENT_BOTTOM;update(x,top,w,y+h-top);}
}
'''
(root/'firmware/src/static_accent.h').write_text(header)
print('Generated',len(masks),'fixed red styles;', [sum(b.bit_count() for b in m) for m in masks])
