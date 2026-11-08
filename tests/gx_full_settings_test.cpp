#include <cassert>
#include <vector>
#include "../firmware/src/full_refresh_settings.h"

struct Write {bool cmd;unsigned char value;};
std::vector<Write> trace;
void command(unsigned char value){trace.push_back({true,value});}
void data(unsigned char value){trace.push_back({false,value});}
static void expect(const Write* expected,unsigned count){
 assert(trace.size()==count);
 for(unsigned i=0;i<count;i++){assert(trace[i].cmd==expected[i].cmd);assert(trace[i].value==expected[i].value);}
}

int main(){
 // Temperature block: only 0xE0/0x41, never 0x50.
 trace.clear();applyGxFullTemperatureSettings(command,data);
 const Write temperature[]={
  {true,0xE0},{false,0x00},
  {true,0x41},{false,0x00}
 };
 expect(temperature,sizeof temperature/sizeof temperature[0]);

 // CDI block: 0x50=0x13/0x07, with red polarity inverted only in the band.
 trace.clear();applyGxFullCdiSettings(command,data);
 const Write cdi[]={
  {true,0x50},{false,0x13},{false,0x07}
 };
 expect(cdi,sizeof cdi/sizeof cdi[0]);
 assert(gxFullCdiRedWire(7999,0x00)==0xFF);
 assert(gxFullCdiRedWire(8000,0x00)==0xFF);
 assert(gxFullCdiRedWire(10399,0x00)==0xFF);
 assert(gxFullCdiRedWire(10400,0x00)==0xFF);
 assert(gxFullCdiRedWire(8000,0xFF)==0x00);
 return 0;
}
