#include <cassert>
#include <cstring>
#include "../firmware/src/refresh_plan.h"
#include "../firmware/src/refresh_regions.h"
uint8_t oldBW[48000],oldRed[48000],bw[48000],red[48000];
int main(){
 memset(oldBW,255,48000);memset(oldRed,255,48000);memset(bw,255,48000);memset(red,255,48000);
 assert(!planRefresh(oldBW,oldRed,bw,red).changed);
 bw[20*100+67]=0;
 auto p=planRefresh(oldBW,oldRed,bw,red);assert(p.x==536&&p.y==20&&p.right==544&&p.bottom==21&&!p.redChanged&&!p.redInWindow);
 oldRed[0]=red[0]=0;assert(!planRefresh(oldBW,oldRed,bw,red).redInWindow);
 oldRed[20*100+67]=red[20*100+67]=0;assert(planRefresh(oldBW,oldRed,bw,red).redInWindow);
 red[1]=0;assert(planRefresh(oldBW,oldRed,bw,red).redChanged);
 memset(oldBW,0,48000);memset(bw,0,48000);bw[47999]=255;memset(oldRed,255,48000);memset(red,255,48000);
 p=planRefresh(oldBW,oldRed,bw,red);assert(p.x==792&&p.y==479&&p.right==800&&p.bottom==480);

 memset(oldBW,255,48000);memset(bw,255,48000);memset(red,255,48000);
 // Layout A: clock and one stock change independently; a red todo is isolated.
 bw[25*100+8]=0;bw[190*100+35]=0;red[170*100+95]=0;
 auto clock=planRegion(oldBW,bw,red,24,0,208,64);
 auto stock=planRegion(oldBW,bw,red,24,184,480,44);
 assert(clock.changed&&!clock.redInWindow&&clock.x==64&&clock.y==25);
 assert(stock.changed&&!stock.redInWindow&&stock.x==280&&stock.y==190);
 red[190*100+35]=0;stock=planRegion(oldBW,bw,red,24,184,480,44);assert(stock.redInWindow);
 assert(!planRegion(oldBW,bw,red,536,160,240,56).changed);
 for(const auto& region:REFRESH_REGIONS){assert(region.x%8==0&&region.w%8==0&&region.x+region.w<=800&&region.y+region.h<=480);}
}
