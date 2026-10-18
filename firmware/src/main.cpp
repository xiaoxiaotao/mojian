#include <Arduino.h>
#include <SPI.h>
#include <WiFi.h>
#include <NimBLEDevice.h>
#include <esp_bt.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "EPD.h"
#include "refresh_plan.h"
#include "paged_plane.h"
#include "refresh_regions.h"
#include "mbedtls/sha256.h"
#if __has_include("wifi_secrets.h")
#include "wifi_secrets.h"
#elif __has_include("../../../../common/config/wifi_secrets.h")
#include "../../../../common/config/wifi_secrets.h"
#else
#define WEATHER_WIFI_SSID ""
#define WEATHER_WIFI_PASSWORD ""
#endif
#if __has_include("device_config.h")
#include "device_config.h"
#else
#include "device_config.example.h"
#endif
constexpr size_t FRAME_BYTES=96000,PLANE_BYTES=48000;
uint8_t *frame=nullptr;
PagedPlane redFrame;
bool bleSuspended=false;
bool localMode=false,legacyPolling=false;
void startBluetooth();
struct FrameLease {
 bool restart;
 FrameLease():restart(NimBLEDevice::getInitialized()){
  if(restart){bleSuspended=true;NimBLEDevice::deinit(true);}
  frame=(uint8_t*)malloc(PLANE_BYTES);redFrame.allocate();
  Serial.printf("Frame lease: BW=%s red=%s heap=%u largest=%u\n",frame?"ok":"fail",redFrame.ready()?"ok":"fail",ESP.getFreeHeap(),ESP.getMaxAllocHeap());
 }
 ~FrameLease(){free(frame);redFrame.release();frame=nullptr;if(restart)startBluetooth();}
};
String previousRedHash;
constexpr size_t REGION_COUNT=sizeof(REFRESH_REGIONS)/sizeof(REFRESH_REGIONS[0]);
String regionRedHash[REGION_COUNT];
String lastAttempt;
extern unsigned char PartImage[]; // kept as positive-polarity BW shadow
String displayed,lastFullRequest;
bool hasBase=false;
unsigned int partialCount=0;
unsigned long lastPoll=0;
bool wifiReported=false;
void authorize(HTTPClient &http){http.addHeader("Authorization",String("Bearer ")+TODO_ACCESS_TOKEN);}
void post(const char* path,JsonDocument& doc){
 HTTPClient http;http.begin(String(TODO_SERVER)+path);authorize(http);http.addHeader("Content-Type","application/json");http.setTimeout(5000);
 String payload;serializeJson(doc,payload);http.POST(payload);http.end();
}
void status(const char* text){JsonDocument doc;doc["message"]=text;post("/api/device/status",doc);}
void ack(const String& request=""){
 JsonDocument doc;doc["revision"]=displayed;if(request.length())doc["full_request"]=request;post("/api/device/ack",doc);
}
String hashBytes(const uint8_t* bytes,size_t length){uint8_t hash[32];mbedtls_sha256_ret(bytes,length,hash,0);char hex[65];for(int i=0;i<32;i++)sprintf(hex+i*2,"%02x",hash[i]);hex[64]=0;return String(hex);}
String redRegionHash(const PagedPlane& red,const ScreenRegion& region){
 mbedtls_sha256_context ctx;mbedtls_sha256_init(&ctx);mbedtls_sha256_starts_ret(&ctx,0);
 for(int y=region.y;y<region.y+region.h;y++)mbedtls_sha256_update_ret(&ctx,red.at(y*100+region.x/8),region.w/8);
 uint8_t digest[32];mbedtls_sha256_finish_ret(&ctx,digest);mbedtls_sha256_free(&ctx);
 char hex[65];for(int i=0;i<32;i++)sprintf(hex+i*2,"%02x",digest[i]);hex[64]=0;return String(hex);
}
String hashRedPlane(){
 mbedtls_sha256_context ctx;mbedtls_sha256_init(&ctx);mbedtls_sha256_starts_ret(&ctx,0);
 for(auto page:redFrame.pages)mbedtls_sha256_update_ret(&ctx,page,PagedPlane::PAGE_BYTES);
 uint8_t hash[32];mbedtls_sha256_finish_ret(&ctx,hash);mbedtls_sha256_free(&ctx);
 char hex[65];for(int i=0;i<32;i++)sprintf(hex+i*2,"%02x",hash[i]);hex[64]=0;return String(hex);
}
void poll(){
 if(localMode||!legacyPolling)return;
 HTTPClient state;state.begin(String(TODO_SERVER)+"/api/device/state");authorize(state);state.setTimeout(10000);
 int code=state.GET();Serial.printf("Device state HTTP=%d heap=%u\n",code,ESP.getFreeHeap());if(code!=200){state.end();return;}
 JsonDocument doc;auto error=deserializeJson(doc,state.getString());state.end();if(error)return;
 String revision=doc["revision"].as<String>();String request=doc["full_request"] | "";
 if(revision.length()!=64)return;
 if(request.length()&&request==lastFullRequest){ack(request);return;}
 if(revision==displayed&&!request.length()){ack();return;}
 if(revision==lastAttempt&&!request.length())return;
 if(!request.length()&&!hasBase){status("设备重启后需要点击一次手动全刷建立基准；不会自动闪刷");return;}
 FrameLease buffer;if(!frame||!redFrame.ready()){status("画面内存不足，本次保留原画面");return;}
 HTTPClient http;http.begin(String(TODO_SERVER)+"/api/device/frame");authorize(http);http.setTimeout(15000);
 if(http.GET()!=200||http.getSize()!=FRAME_BYTES){http.end();return;}
 auto *stream=http.getStreamPtr();size_t n=0;unsigned long start=millis();
 while(n<FRAME_BYTES&&millis()-start<20000){int available=stream->available();if(available>0){size_t offset=n%PLANE_BYTES;size_t count=min((size_t)available,n<PLANE_BYTES?PLANE_BYTES-offset:redFrame.contiguous(offset));n+=stream->readBytes(n<PLANE_BYTES?frame+offset:redFrame.at(offset),count);}else delay(5);}
 http.end();if(n!=FRAME_BYTES)return;
 uint8_t frameHash[32];mbedtls_sha256_context hashContext;mbedtls_sha256_init(&hashContext);mbedtls_sha256_starts_ret(&hashContext,0);mbedtls_sha256_update_ret(&hashContext,frame,PLANE_BYTES);for(auto page:redFrame.pages)mbedtls_sha256_update_ret(&hashContext,page,PagedPlane::PAGE_BYTES);mbedtls_sha256_finish_ret(&hashContext,frameHash);mbedtls_sha256_free(&hashContext);
 char frameHex[65];for(int i=0;i<32;i++)sprintf(frameHex+i*2,"%02x",frameHash[i]);frameHex[64]=0;String actual(frameHex);
 String redHash=hashRedPlane();
 if(!request.length()){
  if(!hasBase){status("设备重启后需要点击一次手动全刷建立基准；不会自动闪刷");return;}
  bool started=false;unsigned int updated=0,blocked=0;unsigned long began=millis();
  for(size_t i=0;i<REGION_COUNT;i++){
   const ScreenRegion& area=REFRESH_REGIONS[i];
   if(redRegionHash(redFrame,area)!=regionRedHash[i]){blocked++;continue;}
   RefreshPlan plan=planRegion(PartImage,frame,redFrame,area.x,area.y,area.w,area.h);
   if(!plan.changed)continue;
   if(plan.redInWindow){blocked++;continue;}
   if(!started){SPI.beginTransaction(SPISettings(10000000,MSBFIRST,SPI_MODE0));EPD_Init_Differential();started=true;}
   unsigned long windowStart=millis();
   EPD_Differential_Rect(PartImage,frame,plan.x,plan.y,plan.right-plan.x,plan.bottom-plan.y);
   for(int y=plan.y;y<plan.bottom;y++)memcpy(PartImage+y*100+plan.x/8,frame+y*100+plan.x/8,(plan.right-plan.x)/8);
   updated++;partialCount++;
   Serial.printf("Region %u window=%d,%d %dx%d duration=%lu ms\n",(unsigned)i,plan.x,plan.y,plan.right-plan.x,plan.bottom-plan.y,millis()-windowStart);
  }
  if(started){EPD_DeepSleep();SPI.endTransaction();}
  lastAttempt=actual;
  bool complete=redHash==previousRedHash && memcmp(PartImage,frame,PLANE_BYTES)==0;
  if(complete){displayed=actual;ack();}
  if(!complete||blocked)status("黑白分区已更新；部分区域含红色变化，等待手动全刷");
  else if(partialCount>=5)status("黑白分区已更新；如见残影可手动清理，不会自动全刷");
  else status("当前画面已分区更新");
  Serial.printf("Region batch updated=%u blocked=%u duration=%lu ms\n",updated,blocked,millis()-began);
  return;
 }else{
  unsigned long began=millis();SPI.beginTransaction(SPISettings(10000000,MSBFIRST,SPI_MODE0));
  for(size_t i=0;i<PLANE_BYTES;i++){frame[i]=~frame[i];redFrame[i]=~redFrame[i];}
  EPD_Init();EPD_WhiteScreen_ALL(frame,nullptr,&redFrame);EPD_DeepSleep();SPI.endTransaction();
  for(size_t i=0;i<PLANE_BYTES;i++){frame[i]=~frame[i];redFrame[i]=~redFrame[i];}
  memcpy(PartImage,frame,PLANE_BYTES);previousRedHash=redHash;hasBase=true;partialCount=0;lastFullRequest=request;lastAttempt="";
  for(size_t i=0;i<REGION_COUNT;i++)regionRedHash[i]=redRegionHash(redFrame,REFRESH_REGIONS[i]);
  Serial.printf("User-requested full refresh duration=%lu ms\n",millis()-began);
 }
 displayed=actual;ack(request);status("当前画面已显示");Serial.println("New task frame displayed");
}
// Finite draw/erase probe in an existing white window, never a looping demo.
void diagnostic(){
 if(!hasBase||!frame||!redFrame.ready()){Serial.println("Probe skipped: no active frame lease");return;}
 if(hashRedPlane()!=previousRedHash){Serial.println("Probe skipped: red shadow changed");return;}
 const unsigned int x=536,y=20,w=80,h=24;
 for(unsigned int row=y;row<y+h;row++)for(unsigned int col=x/8;col<(x+w)/8;col++)if(PartImage[row*100+col]!=255||redFrame[row*100+col]!=255){Serial.println("Probe skipped: window is not white");return;}
 memcpy(frame,PartImage,PLANE_BYTES);
 for(int phase=0;phase<2;phase++){
  for(unsigned int row=y+4;row<y+20;row++)for(unsigned int col=x/8+2;col<x/8+7;col++)frame[row*100+col]=phase?255:0;
  unsigned long began=millis();SPI.beginTransaction(SPISettings(10000000,MSBFIRST,SPI_MODE0));EPD_Init_Differential();EPD_Differential_Rect(PartImage,frame,x,y,w,h);EPD_DeepSleep();SPI.endTransaction();memcpy(PartImage,frame,PLANE_BYTES);
  Serial.printf("Probe %s window=%dx%d duration=%lu ms\n",phase?"erase":"draw",w,h,millis()-began);delay(2000);
 }
 Serial.println("Probe finished; automatic updates remain paused");
}
extern bool autoFetching;
void overlayAutonomy(uint8_t*,const String&);
#include "wifi_provision.h"
#include "local_portal.h"
#include "autonomy.h"
// BLE discovery shares an address only, never credentials.
class DeskEndpointCallbacks : public NimBLECharacteristicCallbacks {
 void onRead(NimBLECharacteristic* characteristic) override {
  String ip=WiFi.status()==WL_CONNECTED?WiFi.localIP().toString():"0.0.0.0";characteristic->setValue((const uint8_t*)ip.c_str(),ip.length());Serial.printf("BLE endpoint read: %s\n",ip.c_str());
 }
};
DeskEndpointCallbacks endpointCallbacks;
class DeskBleCallbacks : public NimBLEServerCallbacks {
 void onConnect(NimBLEServer*) override {Serial.println("BLE connected");}
 void onDisconnect(NimBLEServer*) override {provisionFrames.reset();if(!bleSuspended){NimBLEDevice::startAdvertising();Serial.println("BLE advertising resumed");}}
};
void startBluetooth(){
 bleSuspended=false;
 NimBLEDevice::init("Desk-EPD");
 NimBLEDevice::setSecurityAuth(true,false,true);NimBLEDevice::setSecurityIOCap(BLE_HS_IO_NO_INPUT_OUTPUT);
 NimBLEServer* server=NimBLEDevice::createServer();
 server->setCallbacks(new DeskBleCallbacks());
 NimBLEService* service=server->createService("7f510001-8be5-4b2c-a47f-87c7e72e7050");
 auto* identity=service->createCharacteristic("7f510002-8be5-4b2c-a47f-87c7e72e7050",NIMBLE_PROPERTY::READ);
 identity->setValue("Desk EPD / layout A / BLE identity only");
 auto* endpoint=service->createCharacteristic("7f510003-8be5-4b2c-a47f-87c7e72e7050",NIMBLE_PROPERTY::READ);
 endpoint->setCallbacks(&endpointCallbacks);
 auto* provisioning=service->createCharacteristic("7f510004-8be5-4b2c-a47f-87c7e72e7050",NIMBLE_PROPERTY::READ|NIMBLE_PROPERTY::READ_ENC|NIMBLE_PROPERTY::WRITE|NIMBLE_PROPERTY::WRITE_ENC);provisioning->setCallbacks(&wifiProvisionCallbacks);
 service->start();
 auto* advertising=NimBLEDevice::getAdvertising();
 advertising->addServiceUUID(service->getUUID());
 advertising->setScanResponse(true);
 bool started=advertising->start();
 Serial.printf("BLE advertising %s: Desk-EPD; heap=%u largest=%u\n",started?"started":"FAILED",ESP.getFreeHeap(),ESP.getMaxAllocHeap());
}
void setup(){
 Serial.begin(115200);
 // Free unused Classic BT memory before allocating the large screen frame.
 esp_bt_controller_mem_release(ESP_BT_MODE_CLASSIC_BT);

 pinMode(13,INPUT);pinMode(12,OUTPUT);pinMode(14,OUTPUT);pinMode(27,OUTPUT);digitalWrite(27,HIGH);digitalWrite(12,HIGH);SPI.begin(18,19,23,27);
 beginSavedWifi();configTime(8*3600,0,"ntp.aliyun.com","time.cloudflare.com","pool.ntp.org");
 Serial.printf("WiFi initialized; heap=%u largest=%u\n",ESP.getFreeHeap(),ESP.getMaxAllocHeap());
 startBluetooth();setupLocalPortal();setupAutonomy();Serial.println("Quiet mode: no automatic full refresh");
}
void loop(){
 updateProvisioning();handleLocalPortal();
 updateAutonomy();updateLocalClock();
 if(Serial.available()&&Serial.read()=='t')diagnostic();
 if(WiFi.status()!=WL_CONNECTED){wifiReported=false;delay(1000);return;}
 if(!wifiReported){Serial.printf("WiFi connected with BLE; heap=%u largest=%u\n",ESP.getFreeHeap(),ESP.getMaxAllocHeap());wifiReported=true;}
 if(!lastPoll||millis()-lastPoll>=5000){lastPoll=millis();poll();}delay(20);
}
