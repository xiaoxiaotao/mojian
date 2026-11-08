#pragma once
#include <stdint.h>
struct DisplayGuard {
 bool failed=false,shutdownAttempted=false,shutdownConfirmed=false;uint32_t timeouts=0;
 void reset(){failed=false;shutdownAttempted=false;shutdownConfirmed=false;}
 template<class Busy,class Clock,class Yield> bool wait(Busy busy,Clock clock,Yield yield,uint32_t limit=60000){
  if(failed)return false;
  uint32_t started=clock();
  while(busy()){
   if(uint32_t(clock()-started)>=limit){failed=true;++timeouts;return false;}
   yield();
  }
  return true;
 }
};
