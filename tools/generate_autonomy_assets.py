"""Generate a tiny original bitmap font subset; full Chinese city names are client bitmaps.
Requires Pillow and a local font path, not bundled proprietary font files.
"""
from pathlib import Path
from PIL import Image,ImageFont,ImageDraw
root=Path(__file__).resolve().parents[1]
chars='晴多云雾雨雪阵雷阴旧天气更新℃'
import argparse
p=argparse.ArgumentParser();p.add_argument('--font',required=True);p.add_argument('--digits-font');args=p.parse_args()
font=ImageFont.truetype(args.font,16)
rows=[]
for ch in chars:
 im=Image.new('1',(16,20),1);d=ImageDraw.Draw(im);d.text((0,0),ch,font=font,fill=0,anchor='lt');rows.append(im.tobytes())
p=root/'firmware/src/autonomy_font.h'
p.write_text('#pragma once\n// Glyph data derived from SourceHanSansSC-Medium.otf under SIL OFL 1.1; see firmware/resources/SourceHanSans-OFL.txt.\nstatic const char* AUTO_CHARS="'+chars+'";\nstatic const uint8_t AUTO_GLYPHS[][40]={\n'+',\n'.join('{'+','.join(str(b) for b in row)+'}' for row in rows)+'\n};\n')
certs=''.join((root/'firmware/resources'/name).read_text() for name in ['isrg-root-x1.pem','isrg-root-x2.pem'])
(root/'firmware/src/weather_roots.h').write_text('#pragma once\n// Public ISRG trust anchors. Source: https://letsencrypt.org/certificates/\nstatic const char WEATHER_ROOTS[] PROGMEM=R"CERT('+certs+')CERT";\n')

if args.digits_font:
 glyphs='0123456789:-'
 blocks=['#pragma once','// Generated from unmodified Inter OFL font; see firmware/resources/Inter-OFL.txt.']
 for scale,size,width,height in [(2,14,10,16),(3,28,16,24),(4,32,22,30),(6,52,34,46)]:
  face=ImageFont.truetype(args.digits_font,size);face.set_variation_by_axes([min(size,32),500])
  baseline=-face.getbbox('0123456789',anchor='ls')[1];stride=(width+7)//8;rows=[]
  for char in glyphs:
   im=Image.new('L',(stride*8,height),255);draw=ImageDraw.Draw(im)
   draw.text(((width-face.getlength(char))/2,baseline),char,font=face,fill=0,anchor='ls')
   rows.append(im.point(lambda value:255 if value>=160 else 0,'1').tobytes())
  blocks.append('static const uint8_t AUTO_DIGITS_'+str(scale)+'[12]['+str(stride*height)+']={'+','.join('{'+','.join(str(value) for value in row)+'}' for row in rows)+'};')
 (root/'firmware/src/autonomy_digits.h').write_text('\n'.join(blocks)+'\n')
