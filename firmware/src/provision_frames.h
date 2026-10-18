#pragma once
#include <stdint.h>
#include <stddef.h>
#include <string.h>
class ProvisionFrames {
 char bytes_[257]{};size_t used_=0;bool started_=false;
public:
 enum Result {INVALID,MORE,DONE};
 void reset(){memset(bytes_,0,sizeof bytes_);used_=0;started_=false;}
 const char* data()const{return bytes_;}
 Result feed(const uint8_t* packet,size_t size){if(size<1||size>20){reset();return INVALID;}char op=packet[0];if(op=='S'){reset();started_=true;}else if((op!='C'&&op!='E')||!started_){reset();return INVALID;}if(used_+size-1>256){reset();return INVALID;}for(size_t i=1;i<size;i++){if(!packet[i]){reset();return INVALID;}bytes_[used_++]=(char)packet[i];}bytes_[used_]=0;if(op=='E'){started_=false;return used_?DONE:INVALID;}return MORE;}
};
