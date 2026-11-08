#pragma once
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
// 40 complete scanlines per page; shared by red and local BW input.
// No allocation exceeds 4KB, even when a full frame is required.
struct PagedPlane {
 static constexpr unsigned PAGE_BYTES=4000, PAGE_COUNT=12;
 uint8_t* pages[PAGE_COUNT]={};
 template<class Allocate> bool allocateWith(Allocate allocate){if(ready())return true;for(auto& p:pages){p=(uint8_t*)allocate(PAGE_BYTES);if(!p){release();return false;}}return true;}
 bool allocate(){return allocateWith([](unsigned n){return malloc(n);});}
 bool write(unsigned offset,const uint8_t* data,unsigned length){if(!ready()||offset>PAGE_BYTES*PAGE_COUNT||length>PAGE_BYTES*PAGE_COUNT-offset)return false;while(length){unsigned n=contiguous(offset);if(n>length)n=length;memcpy(at(offset),data,n);offset+=n;data+=n;length-=n;}return true;}
 void copyTo(uint8_t* data)const{for(auto p:pages){memcpy(data,p,PAGE_BYTES);data+=PAGE_BYTES;}}
 void release(){for(auto& p:pages){free(p);p=nullptr;}}
 bool ready()const{return pages[PAGE_COUNT-1]!=nullptr;}
 uint8_t& operator[](unsigned i){return pages[i/PAGE_BYTES][i%PAGE_BYTES];}
 uint8_t operator[](unsigned i)const{return pages[i/PAGE_BYTES][i%PAGE_BYTES];}
 uint8_t* at(unsigned i){return pages[i/PAGE_BYTES]+i%PAGE_BYTES;}
 const uint8_t* at(unsigned i)const{return pages[i/PAGE_BYTES]+i%PAGE_BYTES;}
 unsigned contiguous(unsigned i)const{return PAGE_BYTES-i%PAGE_BYTES;}
};
