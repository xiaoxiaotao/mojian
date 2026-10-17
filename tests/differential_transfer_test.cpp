#include <cassert>
#include <cstring>
#include <vector>
#include "../firmware/src/differential_transfer.h"
struct Write {bool cmd;unsigned char value;};std::vector<Write> trace;
void command(unsigned char value){trace.push_back({true,value});}
void data(unsigned char value){trace.push_back({false,value});}
unsigned char previous[48000],current[48000];
int main(){
 memset(previous,255,sizeof(previous));memset(current,255,sizeof(current));current[300*100+68]=0xa5;
 differentialImages(previous,current,544,300,8,1,command,data);
 assert(trace[0].cmd&&trace[0].value==0x91);assert(trace[1].cmd&&trace[1].value==0x90);
 assert(!trace[10].cmd&&trace[10].value==0); // window-only scanning
 assert(trace[11].cmd&&trace[11].value==0x13);assert(!trace[12].cmd&&trace[12].value==0xff);
 assert(trace[13].cmd&&trace[13].value==0x10);assert(!trace[14].cmd&&trace[14].value==0xa5);
 trace.clear();differentialPlane(0x13,current,544,300,8,1,command,data);
 assert(trace[0].cmd&&trace[0].value==0x13);assert(trace[1].value==0xa5);
}
