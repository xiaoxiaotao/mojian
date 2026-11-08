#include <cassert>
#include <cstdio>
#include "../firmware/src/display_guard.h"
int main(){
 DisplayGuard g;uint32_t now=0;unsigned yields=0;
 auto clock=[&]{return now;};auto yield=[&]{++now;++yields;};
 assert(g.wait([]{return false;},clock,yield)&&yields==0);
 assert(!g.wait([]{return true;},clock,yield,20));assert(now==20&&g.failed&&g.timeouts==1);
 unsigned before=yields;
 // A latched fault blocks subsequent waits even if BUSY returns ready, until explicit recovery.
 assert(!g.wait([]{return false;},clock,yield,20)&&yields==before&&g.timeouts==1);
 g.reset();assert(g.wait([]{return false;},clock,yield)&&!g.failed&&g.timeouts==1);
 now=0xfffffff0U;
 assert(!g.wait([]{return true;},clock,yield,32)&&now==16&&g.timeouts==2);
 g.reset();now=0;assert(g.wait([&]{return now<7;},clock,yield,20)&&now==7&&!g.failed);
 puts("PASS: stuck display exits, fault latches, explicit reset, readiness and rollover");
}
