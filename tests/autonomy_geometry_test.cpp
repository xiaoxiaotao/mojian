#include <cassert>
#include <array>
#include "../firmware/src/autonomy_geometry.h"
int main(){
 for(bool calendar:{false,true})for(bool phone:{false,true}){
  auto c=autoClockRect(calendar,phone),w=autoWeatherRect(calendar,phone);std::array<uint8_t,48000> bytes;bytes.fill(255);
  for(auto rect:{c,w}){assert(rect.x>=0&&rect.y>=0&&rect.x+rect.w<=800&&rect.y+rect.h<=480);assert(rect.y+rect.h<=80||rect.y>103);for(int y=rect.y;y<rect.y+rect.h;y++)for(int x=rect.x;x<rect.x+rect.w;x++)autoPixel(bytes.data(),x,y,false);}
  for(int y=0;y<480;y++)for(int x=0;x<800;x++){bool allowed=(x>=c.x&&x<c.x+c.w&&y>=c.y&&y<c.y+c.h)||(x>=w.x&&x<w.x+w.w&&y>=w.y&&y<w.y+w.h);assert(bool(bytes[y*100+x/8]&(128>>(x%8)))==!allowed);}
  for(int y=80;y<=103;y++)for(int x=0;x<800;x++)autoPixel(bytes.data(),x,y,false);
  for(int y=80;y<=103;y++)for(int b=0;b<100;b++)assert(bytes[y*100+b]==255);
 }
}
