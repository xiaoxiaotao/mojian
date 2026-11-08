// Real pinned panel + base class, detached GPIO/SPI only.
#include "Arduino.h"
#include "SPI.h"
#include "EPD.h"
#include "EPD_SPI.h"
#include "reference_partial.h"
#include <cassert>
#include <cstdio>
#include <fstream>
#include <vector>
uint32_t testMillis=0;
bool testBusyReady=true,testReadyAfterPowerOff=false,testStuckAfterPowerOff=false;
int testDC=0;TestSerial Serial;SPIClass SPI;std::vector<TestTransfer> testTransfers;
extern unsigned char PartImage[];
struct Command {uint8_t value;std::vector<uint8_t> bytes;};
static std::vector<Command> commands(){
 std::vector<Command> result;
 for(auto t:testTransfers){if(!t.dc)result.push_back({t.value,{}});else{assert(!result.empty());result.back().bytes.push_back(t.value);}}
 return result;
}
static std::vector<uint8_t> window(const PagedPlane& image,unsigned x,unsigned y,unsigned w,unsigned h){
 std::vector<uint8_t> bytes;for(unsigned yy=y;yy<y+h;yy++)for(unsigned xx=x/8;xx<(x+w)/8;xx++)bytes.push_back(image[yy*100+xx]);return bytes;
}
int main(int argc,char** argv){
 PagedPlane image;assert(image.allocate());
 for(unsigned i=0;i<48000;i++){PartImage[i]=uint8_t(i*13);image[i]=uint8_t(i*7+19);}
 referencePartialBegin(PartImage);
 auto init=commands();
 for(auto& c:init)assert(c.value!=0x12); // No implicit full refresh/clear.
 auto startup=testTransfers;
 testTransfers.clear();
 // A rectangle crossing the 40-row page boundary at y=240.
 assert(referencePartialRect(PartImage,image,16,220,176,38,true));
 auto trace=commands();unsigned refreshes=0;std::vector<uint8_t> current,previousBefore,previousAfter;
 bool refreshed=false;
 for(auto& c:trace){
  if(c.value==0x12){++refreshes;refreshed=true;}
  if(c.value==0x10)current.insert(current.end(),c.bytes.begin(),c.bytes.end());
  if(c.value==0x13&&!refreshed)previousBefore.insert(previousBefore.end(),c.bytes.begin(),c.bytes.end());
  if(c.value==0x13&&refreshed)previousAfter.insert(previousAfter.end(),c.bytes.begin(),c.bytes.end());
  if(c.value==0x90)assert(c.bytes.size()==9&&c.bytes.back()==0);
 }
 std::vector<uint8_t> expectedPrevious;
 for(unsigned yy=220;yy<258;yy++)for(unsigned xx=2;xx<24;xx++)expectedPrevious.push_back(PartImage[yy*100+xx]);
 assert(previousBefore==expectedPrevious); // Full-frame source stride, not a packed tile.
 assert(refreshes==1&&current==window(image,16,220,176,38)&&previousAfter==current);
 assert(testSPIClock==10000000&&testSPITransactionDepth==0&&testSPITransactionMax==1);
 referencePartialEnd();
 auto finished=commands();for(auto& c:finished)if(c.value==0x50)assert(c.bytes.empty()||c.bytes[0]!=0xf7);
 assert(finished[finished.size()-2].value==0x02&&finished.back().value==0x07);
 if(argc>1){std::ofstream file(argv[1],std::ios::binary);for(auto t:startup){file.put(char(t.dc));file.put(char(t.value));}for(auto t:testTransfers){file.put(char(t.dc));file.put(char(t.value));}}
#ifndef MOJIAN_REFERENCE_UNADAPTED_TEST
 assert(displayTelemetry.refreshCommands==1&&displayTelemetry.refreshCompleted==1);
 assert(displayTelemetry.differentialWindows==1&&displayTelemetry.lastPowerOffBusyReady);
 // Invalid geometry and the red reserve must never transmit anything.
 testTransfers.clear();
 assert(!referencePartialRect(PartImage,image,16,79,176,30,true));
 assert(!referencePartialRect(PartImage,image,17,220,176,30,true));
 assert(!referencePartialRect(PartImage,image,792,220,16,30,true));
 assert(!referencePartialRect(PartImage,image,16,470,176,30,true));
 assert(testTransfers.empty());
 // Source cropping must also hold at the origin, far right and final row,
 // and across successive wake/refresh/sleep cycles.
 const unsigned cases[][4]={{0,104,8,1},{792,479,8,1},{624,318,176,44}};
 for(auto& area:cases){
  referencePartialBegin(PartImage);testTransfers.clear();
  assert(referencePartialRect(PartImage,image,area[0],area[1],area[2],area[3],true));
  std::vector<uint8_t> before,after,now,expected;bool done=false;
  for(auto& c:commands()){
   if(c.value==0x12)done=true;
   if(c.value==0x13){auto& target=done?after:before;target.insert(target.end(),c.bytes.begin(),c.bytes.end());}
   if(c.value==0x10)now.insert(now.end(),c.bytes.begin(),c.bytes.end());
  }
  for(unsigned yy=area[1];yy<area[1]+area[3];yy++)
   for(unsigned xx=area[0]/8;xx<(area[0]+area[2])/8;xx++)expected.push_back(PartImage[yy*100+xx]);
  assert(before==expected&&now==window(image,area[0],area[1],area[2],area[3])&&after==now);
  referencePartialEnd();
 }
 // Refresh timeout: no previous-RAM sync or further drawing; only bounded
 // fixed power-off is allowed by the shared guard after failure.
 referencePartialBegin(PartImage);testTransfers.clear();testBusyOnCommand=0x12;
 assert(!referencePartialRect(PartImage,image,16,220,176,38,true));
 assert(displayGuard.failed&&displayGuard.timeouts==1&&testMillis<31000);
 auto failed=commands();assert(failed.back().value==0x12);
 auto count=testTransfers.size();
 assert(!referencePartialRect(PartImage,image,16,220,176,38,true));assert(testTransfers.size()==count);
 testReadyAfterPowerOff=true;referencePartialEnd();
 assert(displayGuard.failed&&displayGuard.shutdownAttempted&&displayGuard.shutdownConfirmed);
 assert(testSPITransactionDepth==0);
 auto closed=commands();assert(closed[closed.size()-2].value==0x02&&closed.back().value==0x07);
#endif
 image.release();puts("PASS: reference pages/current/previous, window-only scan, no nested SPI/full clear, red protection and fault latch");
}
