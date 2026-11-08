#pragma once
#include "EPD.h"

// Safety/observability bridge for the hash-locked reference base class.
// Panel-specific commands and waveform arrays remain upstream bytes.
namespace mojian_reference_io {
static uint8_t operation=0;
static uint32_t began=0;
inline void command(uint8_t value){
 operation=value;began=millis();
 if(value==0x12)++displayTelemetry.refreshCommands;
 if(value==0x02){
  ++displayTelemetry.powerOffWaits;
  displayTelemetry.lastPowerOffBusyReady=false;
  displayTelemetry.lastPowerOffBusySeen=false;
 }
}
inline void wait(int16_t pin,int16_t active,uint32_t timeoutUs){
 if(displayGuard.failed)return;
 delay(1); // Same assertion margin as the upstream base class.
 bool ready=displayGuard.wait([=]{
  bool busy=digitalRead(pin)==active;
  if(busy&&operation==0x02)displayTelemetry.lastPowerOffBusySeen=true;
  return busy;
 },[]{return (uint32_t)millis();},[]{delay(1);},timeoutUs/1000);
 if(operation==0x12){
  displayTelemetry.lastRefreshWaitMs=uint32_t(millis()-began);
  if(ready)++displayTelemetry.refreshCompleted;
 }
 if(operation==0x02){
  displayTelemetry.lastPowerOffWaitMs=uint32_t(millis()-began);
  displayTelemetry.lastPowerOffBusyReady=ready;
 }
}
}
