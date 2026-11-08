#pragma once
#include <vector>
#include <cassert>
#define MSBFIRST 1
#define SPI_MODE0 0
struct SPISettings {
 unsigned clock;
 SPISettings(unsigned hz=4000000,int=MSBFIRST,int=SPI_MODE0):clock(hz){}
};
inline int testSPITransactionDepth=0,testSPITransactionMax=0,testBusyOnCommand=-1;
inline unsigned testSPIClock=0;
struct TestTransfer {int dc;unsigned char value;};
extern std::vector<TestTransfer> testTransfers;
extern int testDC;
extern bool testBusyReady,testReadyAfterPowerOff,testStuckAfterPowerOff;
struct SPIClass {
 unsigned char transfer(unsigned char value){
  testTransfers.push_back({testDC,value});
  if(!testDC&&value==testBusyOnCommand)testBusyReady=false;
  if(testDelayedPowerOff&&!testDC){
   if(value==0x02){testPowerOffIssued=true;testPowerOffAt=testMillis;}
   if(value==0x07&&testPowerOffIssued&&uint32_t(testMillis-testPowerOffAt)<150)testEarlySleep=true;
  }
  if(!testDC&&value==0x02){if(testReadyAfterPowerOff)testBusyReady=true;if(testStuckAfterPowerOff)testBusyReady=false;}
  return value;
 }
 void begin(int=-1,int=-1,int=-1,int=-1){}
 void beginTransaction(SPISettings settings){
  ++testSPITransactionDepth;assert(testSPITransactionDepth==1);
  testSPITransactionMax=1;testSPIClock=settings.clock;
 }
 void endTransaction(){if(testSPITransactionDepth)--testSPITransactionDepth;}
 void end(){}
};
extern SPIClass SPI;
