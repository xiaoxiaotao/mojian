#pragma once
#include <stdint.h>
struct AutoRect {int x,y,w,h;};
inline AutoRect autoClockRect(bool calendar,bool phone){return calendar&&!phone?AutoRect{650,24,126,50}:AutoRect{24,0,208,80};}
inline AutoRect autoWeatherRect(bool calendar,bool phone){return calendar&&!phone?AutoRect{24,405,280,66}:AutoRect{548,14,228,66};}
inline void autoPixel(uint8_t* bytes,int x,int y,bool white){if(x<0||x>=800||y<0||y>=480||(y>=80&&y<=103))return;uint8_t bit=128>>(x%8);if(white)bytes[y*100+x/8]|=bit;else bytes[y*100+x/8]&=~bit;}
