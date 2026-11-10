#ifdef MOJIAN_EXPERIMENT_GX_REFERENCE
#include "EPD.h"
#include "EPD_SPI.h"
#include "reference_partial.h"
#include <gdey3c/GxEPD2_750c_GDEY075Z08.h>

// Same physical pins and SPI frequency as the A driver. No outer SPI transaction:
// the upstream base class owns each transaction and must never nest ESP32 locks.
static GxEPD2_750c_GDEY075Z08 referencePanel(27,14,12,13);
void referencePartialBegin(const uint8_t* previous){
 if(displayGuard.failed)return;
 referencePanel.selectSPI(SPI,SPISettings(10000000,MSBFIRST,SPI_MODE0));
 referencePanel.init(0,false,10,false);
 referencePanel.writeImageToPrevious(previous,0,0,800,480);
 referencePanel.writeImageToCurrent(previous,0,0,800,480);
}
static void writePages(const PagedPlane& image,unsigned x,unsigned y,unsigned w,unsigned h,bool previous){
 // Each original upstream call receives one real contiguous 40-row bitmap.
 // Writing pages does not refresh them individually; refresh_bw follows once.
 while(h&&!displayGuard.failed){
  unsigned page=y/40,localY=y%40,n=40-localY;if(n>h)n=h;
  if(previous)referencePanel.writeImagePartToPrevious(image.pages[page],x,localY,800,40,x,y,w,n);
  else referencePanel.writeImagePartToCurrent(image.pages[page],x,localY,800,40,x,y,w,n);
  y+=n;h-=n;
 }
}
bool referencePartialRect(const uint8_t* previous,const PagedPlane& current,
                          unsigned x,unsigned y,unsigned w,unsigned h,bool accent){
 if(displayGuard.failed||!current.ready()||!w||!h||x>=800||y>=480||w>800-x||h>480-y||x%8||w%8)return false;
 if(accent&&y<104&&y+h>80)return false;
 // previous is an 800x480 frame, not a tightly packed w-by-h tile.
 // Preserve its source stride and crop at the destination coordinates.
 referencePanel.writeImagePartToPrevious(previous,x,y,800,480,x,y,w,h);
 writePages(current,x,y,w,h,false);
 if(displayGuard.failed)return false;
 ++displayTelemetry.differentialWindows;++displayTelemetry.partialWindowsSinceFull;displayTelemetry.partialAreaSinceFull+=w*h;
 referencePanel.refresh_bw(x,y,w,h);
 if(displayGuard.failed)return false;
 writePages(current,x,y,w,h,true);
 return !displayGuard.failed;
}
void referencePartialEnd(){
 referencePanel.hibernate();
 if(displayGuard.failed){
  SPI.beginTransaction(SPISettings(10000000,MSBFIRST,SPI_MODE0));
  EPD_FaultPowerOff();SPI.endTransaction();
 }
}
#endif
