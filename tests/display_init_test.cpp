// Real driver, detached SPI: initialization order and black-to-white transfer.
#include "Arduino.h"
#include "SPI.h"
#include "EPD.h"
#include "EPD_SPI.h"
#include "partial_lut.h"
#include <cassert>
#include <cstdio>
uint32_t testMillis=0;
bool testBusyReady=true,testReadyAfterPowerOff=false,testStuckAfterPowerOff=false;
int testDC=0;TestSerial Serial;SPIClass SPI;std::vector<TestTransfer> testTransfers;
extern unsigned char PartImage[];
struct Command {unsigned char value;std::vector<unsigned char> data;};
static std::vector<Command> commands(){
 std::vector<Command> out;
 for(auto t:testTransfers){if(!t.dc)out.push_back({t.value,{}});else{assert(!out.empty());out.back().data.push_back(t.value);}}
 return out;
}
int main(){
 for(unsigned i=0;i<48000;i++)PartImage[i]=(i%2)?0xff:0x00;
 EPD_Init_Differential();auto init=commands();
#ifdef MOJIAN_EXPERIMENT_BW_INIT
 const unsigned char expected[]={0x01,0x06,0x00,0x61,0x15,0x50,0x60,0x00,0x82,0x50,0x20,0x21,0x22,0x23,0x24,0x25,0x04,0x10,0x13};
 assert(init.size()==sizeof expected);
 for(unsigned i=0;i<init.size();i++)assert(init[i].value==expected[i]);
 assert(init[0].data==std::vector<unsigned char>({7,7,0x3f,0x3f}));
 assert(init[1].data==std::vector<unsigned char>({0x17,0x17,0x28,0x17}));
 assert(init[3].data==std::vector<unsigned char>({3,0x20,1,0xe0}));
 const unsigned char* tables[]={lut_20_LUTC,lut_21_LUTWW,lut_22_LUTKW,lut_23_LUTWK,lut_24_LUTKK,lut_25_LUTBD};
 for(unsigned t=0;t<6;t++)assert(init[10+t].data==std::vector<unsigned char>(tables[t],tables[t]+42));
 for(unsigned t=17;t<19;t++)assert(init[t].data==std::vector<unsigned char>(PartImage,PartImage+48000));
#endif
 // One erased byte: old black must be sent as previous, white as current,
 // then white copied into previous RAM after DISPLAY_REFRESH.
 static unsigned char oldFrame[48000],newFrame[48000];
 for(unsigned i=0;i<48000;i++)oldFrame[i]=newFrame[i]=0xff;
 oldFrame[22000]=0x00;
 testTransfers.clear();EPD_Differential_Rect(oldFrame,newFrame,0,220,8,1);
 assert(displayTelemetry.refreshCommands==1&&displayTelemetry.refreshCompleted==1);
 assert(displayTelemetry.differentialWindows==1&&displayTelemetry.lastRefreshWaitMs>=1);
 auto erase=commands();const unsigned char order[]={0x91,0x90,0x13,0x10,0x12,0x92,0x91,0x90,0x13,0x92};
 assert(erase.size()==sizeof order);
 for(unsigned i=0;i<erase.size();i++)assert(erase[i].value==order[i]);
 assert(erase[2].data==std::vector<unsigned char>({0x00}));
 assert(erase[3].data==std::vector<unsigned char>({0xff}));
 assert(erase[8].data==std::vector<unsigned char>({0xff}));
 assert(erase[1].data.back()==0 && erase[7].data.back()==0);
 testTransfers.clear();EPD_DeepSleep();auto sleep=commands();
#ifndef MOJIAN_EXPERIMENT_BW_SLEEP
 assert(sleep.size()==3&&sleep[0].value==0x50&&sleep[0].data==std::vector<unsigned char>({0xf7}));
#endif

 // Fragmented frame storage must emit exactly the same SPI bytes as flat
 // storage, including a window crossing the 4KB page boundary at row 40.
 PagedPlane paged;assert(paged.allocate());
 for(unsigned i=0;i<48000;i++)newFrame[i]=(unsigned char)(i%251);
 assert(paged.write(0,newFrame,48000));
 auto sameTransfers=[](const std::vector<TestTransfer>& flat){assert(flat.size()==testTransfers.size());for(unsigned i=0;i<flat.size();i++)assert(flat[i].dc==testTransfers[i].dc&&flat[i].value==testTransfers[i].value);};
 testTransfers.clear();EPD_Differential_Rect(oldFrame,newFrame,0,39,800,3);auto flatPartial=testTransfers;
 testTransfers.clear();EPD_Differential_Rect(oldFrame,paged,0,39,800,3);sameTransfers(flatPartial);
 testTransfers.clear();EPD_WhiteScreen_ALL(newFrame,nullptr,nullptr,true,0);auto flatFull=testTransfers;
 auto full=commands();
#ifdef MOJIAN_EXPERIMENT_GX_FULL
 assert(full.size()==7);
 assert(full[2].value==0x00&&full[2].data==std::vector<unsigned char>({0x0f}));
 assert(full[3].value==0x50&&full[3].data==std::vector<unsigned char>({0x13,0x07}));
 assert(full[4].value==0xE0&&full[4].data==std::vector<unsigned char>({0x00}));
 assert(full[5].value==0x41&&full[5].data==std::vector<unsigned char>({0x00}));
 assert(full[6].value==0x12);
#else
 assert(full.size()==3&&full[0].value==0x10&&full[1].value==0x13&&full[2].value==0x12);
#endif
 testTransfers.clear();EPD_WhiteScreen_ALL(nullptr,nullptr,nullptr,true,0,&paged);sameTransfers(flatFull);paged.release();
 puts("PASS: real driver initialization, erase old/current/sync planes, window-only scan and shutdown isolation");
}
