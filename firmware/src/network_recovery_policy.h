#pragma once
#include <stdint.h>
// Unsigned elapsed arithmetic remains valid across the millis() rollover.
struct NetworkRecoveryPolicy {
 uint32_t since=0,attemptAt=0;unsigned attempts=0;bool offline=false;
 void connected(){offline=false;attempts=0;}
 void pause(uint32_t now){offline=true;since=attemptAt=now;attempts=0;}
 unsigned next(uint32_t now,bool connectedNow,bool paused){
  if(paused){pause(now);return 0;}
  if(connectedNow){connected();return 0;}
  if(!offline){pause(now);return 0;}
  uint32_t interval=attempts==0?15000U:attempts==1?30000U:60000U;
  if(uint32_t(now-attemptAt)<interval)return 0;
  attemptAt=now;++attempts;
  return attempts%4==0?2:1; // reconnect first; periodically restart only the Wi-Fi radio.
 }
};
