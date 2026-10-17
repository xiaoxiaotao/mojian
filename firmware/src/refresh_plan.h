#pragma once
#include <stdint.h>
struct RefreshPlan {int x=800,y=480,right=0,bottom=0;bool redChanged=false,redInWindow=false;bool changed=false;};
inline RefreshPlan planRefresh(const uint8_t* oldBW,const uint8_t* oldRed,const uint8_t* bw,const uint8_t* red){
 RefreshPlan p;
 for(int y=0;y<480;y++)for(int col=0;col<100;col++){
  int i=y*100+col;if(oldRed[i]!=red[i])p.redChanged=true;
  if(oldBW[i]!=bw[i]){p.changed=true;if(col*8<p.x)p.x=col*8;if(y<p.y)p.y=y;if((col+1)*8>p.right)p.right=(col+1)*8;if(y+1>p.bottom)p.bottom=y+1;}
 }
 if(p.changed)for(int y=p.y;y<p.bottom;y++)for(int col=p.x/8;col<p.right/8;col++)if(oldRed[y*100+col]!=255||red[y*100+col]!=255)p.redInWindow=true;
 return p;
}

// Independent region planning; caller establishes red-plane equality for this region.
template<class RedPlane>
inline RefreshPlan planRegion(const uint8_t* oldBW,const uint8_t* bw,const RedPlane& red,int x,int y,int w,int h){
 RefreshPlan p;
 for(int row=y;row<y+h;row++)for(int col=x/8;col<(x+w)/8;col++)if(oldBW[row*100+col]!=bw[row*100+col]){
  p.changed=true;if(col*8<p.x)p.x=col*8;if(row<p.y)p.y=row;if((col+1)*8>p.right)p.right=(col+1)*8;if(row+1>p.bottom)p.bottom=row+1;
 }
 if(p.changed)for(int row=p.y;row<p.bottom;row++)for(int col=p.x/8;col<p.right/8;col++)if(red[row*100+col]!=255)p.redInWindow=true;
 return p;
}
