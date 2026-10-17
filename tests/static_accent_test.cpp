#include <cassert>
#include "../firmware/src/static_accent.h"
int main(){
 int red=0,windows=0;
 for(unsigned i=0;i<48000;i++){auto b=staticAccentWire(i);if(i<8000||i>=10400)assert(b==0);for(int bit=0;bit<8;bit++)red+=(b>>bit)&1;}
 assert(red>300);
 for(unsigned style=0;style<8;style++){int pixels=0;for(unsigned i=0;i<48000;i++){auto b=staticAccentWire(i,style);if(i<8000||i>=10400)assert(b==0);for(int bit=0;bit<8;bit++)pixels+=(b>>bit)&1;}assert(pixels>300);}
 assert(accentStyleIndex("agenda")==1 && accentStyleIndex("calendar")==7 && accentStyleIndex("unknown")==-1);
 for(int y=0;y<480;y+=80)for(int x=0;x<800;x+=200){withoutAccent(x,y,200,80,[&](int a,int b,int w,int h){assert(h>0&&w==200&&a==x);assert(b+h<=80||b>=104);windows++;});}
 assert(windows==24);
 // A region straddling the band must become two independent windows.
 int pieces=0;withoutAccent(0,70,800,50,[&](int,int y,int,int h){assert((y==70&&h==10)||(y==104&&h==16));pieces++;});assert(pieces==2);
}
