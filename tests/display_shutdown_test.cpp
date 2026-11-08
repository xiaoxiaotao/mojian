// Compile the real display driver with detached GPIO/SPI stubs; no hardware I/O.
#include "Arduino.h"
#include "SPI.h"
#include "EPD.h"
#include "EPD_SPI.h"
#include <cassert>
#include <cstdio>
uint32_t testMillis=0;
bool testBusyReady=true,testReadyAfterPowerOff=false,testStuckAfterPowerOff=false;
int testDC=0;
TestSerial Serial;
SPIClass SPI;
std::vector<TestTransfer> testTransfers;
extern void EPD_Update();
static void reset(){displayGuard.reset();testMillis=0;testBusyReady=true;testReadyAfterPowerOff=false;testStuckAfterPowerOff=false;testDelayedPowerOff=false;testPowerOffIssued=false;testEarlySleep=false;testTransfers.clear();}
static void expect(unsigned i,int dc,unsigned char value){assert(i<testTransfers.size());assert(testTransfers[i].dc==dc&&testTransfers[i].value==value);}
int main(){
 reset();EPD_DeepSleep();assert(!displayGuard.failed);assert(testTransfers.size()==5);
 assert(displayTelemetry.powerOffWaits==1&&displayTelemetry.lastPowerOffBusyReady);
 assert(!displayTelemetry.lastPowerOffBusySeen);
 assert(displayTelemetry.lastPowerOffWaitMs==1&&displayTelemetry.refreshCommands==0);
 expect(0,0,0x50);expect(1,1,0xf7);expect(2,0,0x02);expect(3,0,0x07);expect(4,1,0xa5);
 // Exercise the real differential initialization before checking shutdown:
 // experiment must omit 0x50 only here, never in full/color initialization.
 reset();EPD_Init_Differential();testTransfers.clear();EPD_DeepSleep();
#ifdef MOJIAN_EXPERIMENT_BW_SLEEP
 assert(testTransfers.size()==3);expect(0,0,0x02);expect(1,0,0x07);expect(2,1,0xa5);
#else
 assert(testTransfers.size()==5);expect(0,0,0x50);expect(1,1,0xf7);
#endif
 reset();EPD_Init_Differential();EPD_Init();testTransfers.clear();EPD_DeepSleep();
 assert(testTransfers.size()==5);expect(0,0,0x50);expect(1,1,0xf7);
 // A refresh timeout used to suppress every shutdown byte. Recovering BUSY
 // after POWER_OFF now permits sleep, without re-enabling drawing.
 reset();EPD_Init();testBusyReady=false;uint32_t refreshBefore=displayTelemetry.refreshCommands;
 uint32_t completedBefore=displayTelemetry.refreshCompleted;
 EPD_Update();assert(displayGuard.failed&&displayGuard.timeouts>0);
 assert(displayTelemetry.refreshCommands==refreshBefore+1&&displayTelemetry.refreshCompleted==completedBefore);
 assert(displayTelemetry.lastRefreshWaitMs>=60000);
 testTransfers.clear();testReadyAfterPowerOff=true;uint32_t before=testMillis;
 EPD_DeepSleep();assert(displayGuard.failed&&displayGuard.shutdownAttempted&&displayGuard.shutdownConfirmed);
 assert(testMillis-before<=1001);assert(testTransfers.size()==3);expect(0,0,0x02);expect(1,0,0x07);expect(2,1,0xa5);
 EPD_W21_WriteCMD(0x12);EPD_W21_WriteDATA(0xff);EPD_DeepSleep();assert(testTransfers.size()==3);
 // A permanently stuck BUSY has a bounded best-effort power-off, no claim
 // of confirmed shutdown, no sleep while busy, and no repeated attempts.
 reset();displayGuard.failed=true;testBusyReady=false;EPD_DeepSleep();
 assert(displayGuard.failed&&displayGuard.shutdownAttempted&&!displayGuard.shutdownConfirmed);
 assert(testMillis==1001&&testTransfers.size()==1);expect(0,0,0x02);EPD_DeepSleep();assert(testTransfers.size()==1&&testMillis==1001);
 // A timeout during normal POWER_OFF also takes the bounded fault path.
 reset();testStuckAfterPowerOff=true;EPD_DeepSleep();assert(displayGuard.failed&&displayGuard.shutdownAttempted&&!displayGuard.shutdownConfirmed);
 assert(testMillis==61002&&testTransfers.size()==4);expect(2,0,0x02);expect(3,0,0x02);
 assert(!displayTelemetry.lastPowerOffBusyReady&&displayTelemetry.lastPowerOffWaitMs>=60000);
 // Only an explicit reset restores drawing and allows a new fault attempt.
 displayGuard.reset();assert(!displayGuard.shutdownAttempted&&!displayGuard.shutdownConfirmed);EPD_W21_WriteCMD(0x10);assert(testTransfers.size()==5);
 // BUSY may initially remain ready after POWER_OFF, then assert. The
 // post-wait sleep delay cannot replace waiting for the actual completion.
 reset();testDelayedPowerOff=true;EPD_DeepSleep();
 assert(!displayGuard.failed&&!testEarlySleep&&testMillis>=250);
 assert(displayTelemetry.lastPowerOffBusyReady&&displayTelemetry.lastPowerOffWaitMs==150);
 assert(displayTelemetry.lastPowerOffBusySeen);
 assert(testTransfers.size()==5);expect(3,0,0x07);expect(4,1,0xa5);
 reset();testMillis=0xfffffff0U;displayGuard.failed=true;testBusyReady=false;EPD_DeepSleep();assert(testMillis==985U&&testTransfers.size()==1);
 puts("PASS: real EPD/SPI normal sleep, timeout shutdown, fixed-byte bypass, latch, bounded BUSY and rollover");
}
