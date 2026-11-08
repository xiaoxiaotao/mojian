#include <cassert>
#include <vector>
#include "../firmware/src/full_refresh_settings.h"

struct Write {bool cmd;unsigned char value;};
std::vector<Write> trace;
void command(unsigned char value){trace.push_back({true,value});}
void data(unsigned char value){trace.push_back({false,value});}

int main(){
 applyGxFullTemperatureSettings(command,data);
 const Write expected[]={
  {true,0xE0},{false,0x00},
  {true,0x41},{false,0x00}
 };
 assert(trace.size()==sizeof expected/sizeof expected[0]);
 for(unsigned i=0;i<trace.size();i++){
  assert(trace[i].cmd==expected[i].cmd);
  assert(trace[i].value==expected[i].value);
 }
 return 0;
}
