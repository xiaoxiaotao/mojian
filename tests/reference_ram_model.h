#pragma once
#include <array>
#include <vector>
#include <cassert>
// Detached controller-RAM contract only; it does not model pigment or voltage.
// Decode actual SPI output rather than mirroring the adapter's source indexing.
inline void checkReferenceRamTrace(const std::array<uint8_t,48000>& displayed,
                                  const std::array<uint8_t,48000>& target){
 struct Command {uint8_t value;std::vector<uint8_t> bytes;};
 std::vector<Command> commands;
 for(auto t:testTransfers){
  if(!t.dc)commands.push_back({t.value,{}});
  else {assert(!commands.empty());commands.back().bytes.push_back(t.value);}
 }
 auto logical=displayed; // Expected logical image, not an optical simulation.
 std::array<uint8_t,48000> previous{},current{};
 unsigned x=0,y=0,w=800,h=480,refreshes=0;
 for(const auto& c:commands){
  if(c.value==0x90){
   assert(c.bytes.size()==9&&c.bytes[8]==0);
   x=(unsigned(c.bytes[0])<<8)|c.bytes[1];
   unsigned right=(unsigned(c.bytes[2])<<8)|c.bytes[3];
   y=(unsigned(c.bytes[4])<<8)|c.bytes[5];
   unsigned bottom=(unsigned(c.bytes[6])<<8)|c.bytes[7];
   assert(right>=x&&bottom>=y&&right<800&&bottom<480&&x%8==0);
   w=right-x+1;h=bottom-y+1;assert(w%8==0);
  }
  if(c.value==0x13||c.value==0x10){
   assert(c.bytes.size()==w/8*h);
   auto& bank=c.value==0x13?previous:current;unsigned n=0;
   for(unsigned yy=y;yy<y+h;yy++)for(unsigned xx=x/8;xx<(x+w)/8;xx++)bank[yy*100+xx]=c.bytes[n++];
  }
  if(c.value==0x12){
   ++refreshes;
   assert(!(y<104&&y+h>80)); // Fixed accent reserve must never be scanned.
   for(unsigned yy=y;yy<y+h;yy++)for(unsigned xx=x/8;xx<(x+w)/8;xx++){
    unsigned at=yy*100+xx;
    assert(previous[at]==logical[at]);
    assert(current[at]==target[at]);
    logical[at]=current[at];
   }
  }
 }
 assert(refreshes>0&&logical==target);
 // After the final previous sync both banks must match the committed frame.
 assert(previous==target&&current==target);
}
