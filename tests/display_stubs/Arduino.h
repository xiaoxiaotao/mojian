#pragma once
#include <cstdint>
#include "pgmspace.h"
#define LOW 0
#define HIGH 1
#define INPUT 0
#define OUTPUT 1
#define INPUT_PULLUP 2
#define PROGMEM
extern uint32_t testMillis;
extern bool testBusyReady;
extern int testDC;
// Optional delayed-assertion model for the real driver's power-off wait.
inline bool testDelayedPowerOff=false,testPowerOffIssued=false,testEarlySleep=false;
inline uint32_t testPowerOffAt=0;
inline void delay(unsigned n){testMillis+=n;}
inline void delayMicroseconds(unsigned){}
inline uint32_t millis(){return testMillis;}
inline uint32_t micros(){return testMillis*1000;}
inline void yield(){}
inline int digitalRead(int){
 if(testDelayedPowerOff&&testPowerOffIssued){
  uint32_t elapsed=testMillis-testPowerOffAt;
  return elapsed<1||elapsed>=150;
 }
 return testBusyReady;
}
inline void digitalWrite(int pin,int value){if(pin==14)testDC=value;}
inline void pinMode(int,int){}
struct TestSerial {
 void begin(unsigned){}
 template<class T> void println(T){}
 template<class T> void print(T){}
 template<class... T> void printf(const char*,T...){}
};
extern TestSerial Serial;
