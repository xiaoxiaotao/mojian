#pragma once
#include <stdint.h>
#include <stdlib.h>
// 40 complete scanlines per page; avoids a 48KB contiguous red allocation.
struct PagedPlane {
 static constexpr unsigned PAGE_BYTES=4000, PAGE_COUNT=12;
 uint8_t* pages[PAGE_COUNT]={};
 bool allocate(){for(auto& p:pages){p=(uint8_t*)malloc(PAGE_BYTES);if(!p){release();return false;}}return true;}
 void release(){for(auto& p:pages){free(p);p=nullptr;}}
 bool ready()const{return pages[PAGE_COUNT-1]!=nullptr;}
 uint8_t& operator[](unsigned i){return pages[i/PAGE_BYTES][i%PAGE_BYTES];}
 uint8_t operator[](unsigned i)const{return pages[i/PAGE_BYTES][i%PAGE_BYTES];}
 uint8_t* at(unsigned i){return pages[i/PAGE_BYTES]+i%PAGE_BYTES;}
 const uint8_t* at(unsigned i)const{return pages[i/PAGE_BYTES]+i%PAGE_BYTES;}
 unsigned contiguous(unsigned i)const{return PAGE_BYTES-i%PAGE_BYTES;}
};
