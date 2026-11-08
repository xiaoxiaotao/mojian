#include "../firmware/src/frame_borrow.h"
#include <cassert>
#include <cstdio>
int main(){
 bool suspended=false,restart=false;int attempts=0;unsigned char pixel=255;
 auto acquire=[&](bool fail){return acquireBorrowedFrame([&]{suspended=true;},[&]()->unsigned char*{++attempts;return fail?nullptr:&pixel;},[&]{if(suspended)restart=true;});};
 assert(!acquire(true));assert(suspended&&restart&&attempts==1);
 // A failed attempt schedules restoration even if no subsequent request runs.
 suspended=false;restart=false;assert(acquire(false)==&pixel);assert(suspended&&!restart&&attempts==2);
 // Success hands the buffer to its owner; restoration belongs to release.
 if(suspended)restart=true;assert(restart);
 puts("PASS: frame allocation failure restores BLE lease; success transfers ownership");
}
