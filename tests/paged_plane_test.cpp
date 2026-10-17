#include <cassert>
#include <cstring>
#include "../firmware/src/paged_plane.h"
#include "../firmware/src/refresh_plan.h"
uint8_t oldBW[48000],bw[48000],red[48000];
int main(){
 PagedPlane p;assert(p.allocate());
 for(unsigned i=0;i<48000;i++)p[i]=red[i]=(i%251);
 for(unsigned i=0;i<48000;i++)assert(p[i]==red[i]);
 assert(p.contiguous(3999)==1&&p.contiguous(4000)==4000);
 assert(p.at(4000)==p.pages[1]);
 memset(oldBW,255,sizeof oldBW);memset(bw,255,sizeof bw);
 for(unsigned i=0;i<48000;i++)p[i]=red[i]=255;
 bw[3999]=bw[4000]=0;p[4000]=red[4000]=0;
 auto paged=planRegion(oldBW,bw,p,0,0,800,480);
 auto flat=planRegion(oldBW,bw,red,0,0,800,480);
 assert(paged.changed&&paged.redInWindow&&paged.x==flat.x&&paged.bottom==flat.bottom&&paged.right==flat.right);
 p.release();assert(!p.ready());assert(p.allocate());p.release();
}
