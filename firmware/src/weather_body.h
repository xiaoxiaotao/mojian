#pragma once
#include <stdint.h>
#include <stddef.h>
// Detached HTTP body reader. getStreamPtr() exposes raw chunk framing, so decode
// it here rather than HTTPClient::getString()/writeToStream (unbounded growth /
// per-read timeout). Body, framing, idle and total work all have hard limits.
// Caller supplies capacity + 1 bytes; the final byte is a JSON terminator.
template<class Source,class Clock,class Yield>
bool readWeatherBody(Source& source,bool chunked,int length,char* body,size_t capacity,size_t& used,Clock clock,Yield yield,uint32_t totalMs=15000,uint32_t idleMs=3000){
 used=0;if(capacity>8192)capacity=8192;if(!body||capacity==0||length< -1||(!chunked&&length>=0&&size_t(length)>capacity))return false;
 const uint32_t started=clock();uint32_t active=started;size_t wire=0;
 auto read=[&]()->int{
  for(;;){
   uint32_t now=clock();if(uint32_t(now-started)>=totalMs||uint32_t(now-active)>=idleMs)return -2;
   if(source.available()>0){int value=source.read();if(value>=0){if(++wire>16384)return -2;active=clock();return value;}}
   else if(!source.connected())return -1;
   yield();
  }
 };
 auto line=[&](char* text,size_t size,size_t& count)->bool{
  count=0;for(;;){int c=read();if(c<0)return false;if(c=='\r'){if(read()!='\n')return false;text[count]=0;return true;}if(c=='\n'||c==0||count+1>=size)return false;text[count++]=(char)c;}
 };
 if(chunked){
  char header[129];size_t n=0;
  for(;;){
   if(!line(header,sizeof header,n)||!n)return false;
   size_t chunk=0,digits=0;
   for(size_t i=0;i<n&&header[i]!=';';i++){
    unsigned char c=header[i];int digit=c>='0'&&c<='9'?c-'0':c>='a'&&c<='f'?c-'a'+10:c>='A'&&c<='F'?c-'A'+10:-1;
    if(digit<0||chunk>capacity/16)return false;chunk=chunk*16+digit;++digits;if(chunk>capacity-used)return false;
   }
   if(!digits)return false;
   if(!chunk){
    // Bound trailer line and aggregate wire bytes; wait for terminating CRLF.
    do{if(!line(header,sizeof header,n))return false;}while(n);
    body[used]=0;return true;
   }
   for(size_t i=0;i<chunk;i++){int c=read();if(c<0)return false;body[used++]=(char)c;}
   if(read()!='\r'||read()!='\n')return false;
  }
 }
 while(length<0||used<size_t(length)){
  int c=read();if(c==-1&&length<0){body[used]=0;return true;}if(c<0||used>=capacity)return false;body[used++]=(char)c;
 }
 body[used]=0;return true;
}
