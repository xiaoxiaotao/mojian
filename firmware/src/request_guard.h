#pragma once
#include <stdint.h>
#include <stddef.h>

// One synchronous HTTP parser owns this reader. No background timer may free its
// frame while the parser is running. Bounds must be enforced inside every read.
template<class Client> class MojianRequestReader {
 public:
  static constexpr uint32_t IDLE_MS=5000, TOTAL_MS=30000;
  static constexpr size_t HEADER_LIMIT=8192, BODY_LIMIT=60000;
  static constexpr size_t HEADER_LINE_LIMIT=1024, FIELD_LIMIT=8192;
  void begin(Client& value){client=&value;began=lastByte=millis();received=0;body=false;bad=false;}
  bool failed()const{return bad;}
  void reject(){bad=true;}
  void beginBody(){body=true;received=0;}
  int readByte(){
   if(bad||!client)return -1;
   for(;;){
    uint32_t now=millis();
    if(uint32_t(now-began)>=TOTAL_MS||uint32_t(now-lastByte)>=IDLE_MS){bad=true;return -1;}
    if(client->available()){
     int byte=client->read();
     if(byte>=0){if(++received>(body?BODY_LIMIT:HEADER_LIMIT)){bad=true;return -1;}lastByte=now;return byte;}
    }
    if(!client->connected()){bad=true;return -1;}
    delay(1);
   }
  }
  String readStringUntil(char delimiter){
   String line;
   for(;;){int byte=readByte();if(byte<0)return line;if(byte==delimiter)return line;
    if(line.length()>=(body?FIELD_LIMIT:HEADER_LINE_LIMIT)){bad=true;return line;}line+=(char)byte;}
  }
  size_t readBytes(char* target,size_t length){
   size_t count=0;while(count<length){int byte=readByte();if(byte<0)break;target[count++]=(char)byte;}return count;
  }
 private:
  Client* client=nullptr;
  uint32_t began=0,lastByte=0;
  size_t received=0;
  bool body=false,bad=false;
};
