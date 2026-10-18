"""Generate a tiny original bitmap font subset; full Chinese city names are client bitmaps.
Requires Pillow and a local font path, not bundled proprietary font files.
"""
from pathlib import Path
from PIL import Image,ImageFont,ImageDraw
root=Path(__file__).resolve().parents[1]
chars='晴多云雾雨雪阵雷阴旧天气更新℃'
import argparse
p=argparse.ArgumentParser();p.add_argument('--font',required=True);args=p.parse_args()
font=ImageFont.truetype(args.font,16)
rows=[]
for ch in chars:
 im=Image.new('1',(16,20),1);d=ImageDraw.Draw(im);d.text((0,0),ch,font=font,fill=0,anchor='lt');rows.append(im.tobytes())
p=root/'firmware/src/autonomy_font.h'
p.write_text('#pragma once\n// Generated glyph pixels only; do not bundle the source font.\nstatic const char* AUTO_CHARS="'+chars+'";\nstatic const uint8_t AUTO_GLYPHS[][40]={\n'+',\n'.join('{'+','.join(str(b) for b in row)+'}' for row in rows)+'\n};\n')
certs=''.join((root/'firmware/resources'/name).read_text() for name in ['isrg-root-x1.pem','isrg-root-x2.pem'])
(root/'firmware/src/weather_roots.h').write_text('#pragma once\n// Public ISRG trust anchors. Source: https://letsencrypt.org/certificates/\nstatic const char WEATHER_ROOTS[] PROGMEM=R"CERT('+certs+')CERT";\n')
