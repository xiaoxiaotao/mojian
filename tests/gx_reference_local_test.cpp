#include "Arduino.h"
#include "SPI.h"
#include "EPD.h"
#include "EPD_SPI.h"
#include "reference_partial.h"
#include "refresh_plan.h"
#include "refresh_regions.h"
#include "static_accent.h"
#include <cassert>
#include <cstdio>
#include <vector>
uint32_t testMillis=0;
bool testBusyReady=true,testReadyAfterPowerOff=false,testStuckAfterPowerOff=false;
int testDC=0;TestSerial Serial;SPIClass SPI;std::vector<TestTransfer> testTransfers;
extern unsigned char PartImage[];
constexpr unsigned PLANE_BYTES=48000;
bool hasBase=true;
PagedPlane* localIncoming=nullptr;
struct WhitePlane {uint8_t operator[](unsigned)const{return 255;}};
#include "actual_local_paint.h"
#include "reference_ram_model.h"
int main(){
 PagedPlane image;assert(image.allocate());localIncoming=&image;
 for(unsigned i=0;i<48000;i++)PartImage[i]=image[i]=255;
 assert(localPaint(image,false,true,true,0));assert(testTransfers.empty());
 // Replay additions, erasures, moving marks and several independent windows.
 // Each wake resets RAM; the trace must still supply the exact old/new planes.
 for(unsigned round=0;round<12;round++){
  std::array<uint8_t,48000> old{},target{};
  for(unsigned i=0;i<48000;i++){old[i]=PartImage[i];image[i]=255;}
  const unsigned origins[]={30*100+82,188*100+4,238*100+76,410*100+5,478*100+99};
  for(unsigned k=0;round%4!=3&&k<5;k++){
   unsigned pos=origins[k]+(round%2)*100;
   image[pos]=uint8_t(0x81u^(round*17+k*23));
  }
  for(unsigned i=0;i<48000;i++)target[i]=image[i];
  testTransfers.clear();assert(localPaint(image,false,true,true,0));
  checkReferenceRamTrace(old,target);
  for(unsigned i=0;i<48000;i++)assert(PartImage[i]==target[i]);
 }
 for(unsigned i=0;i<48000;i++)PartImage[i]=image[i]=255;
 testTransfers.clear();displayTelemetry.refreshCommands=0;displayTelemetry.refreshCompleted=0;displayTelemetry.differentialWindows=0;
 image[220*100+10]=0;
 assert(localPaint(image,false,true,true,0));
 assert(hasBase&&!displayGuard.failed&&testSPITransactionDepth==0&&testSPITransactionMax==1);
 assert(displayTelemetry.refreshCommands==1&&displayTelemetry.differentialWindows==1);
 assert(PartImage[220*100+10]==0);
 auto count=testTransfers.size();assert(localPaint(image,false,true,true,0));assert(count==testTransfers.size());
 image[221*100+10]=0;testBusyOnCommand=0x12;testReadyAfterPowerOff=true;
 assert(!localPaint(image,false,true,true,0));
 assert(!hasBase&&displayGuard.failed&&displayGuard.shutdownConfirmed&&testSPITransactionDepth==0);
 // Explicit full baseline remains the A path and clears the fault only here.
 testBusyOnCommand=-1;testBusyReady=true;
 assert(localPaint(image,true,true,true,0));assert(hasBase&&!displayGuard.failed&&testSPITransactionDepth==0);
 assert(image[220*100+10]==0&&image[221*100+10]==0);
 image.release();puts("PASS: real localPaint reference integration, no-op skip, no nested SPI, failure ownership and explicit full recovery");
}
