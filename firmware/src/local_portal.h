#pragma once
#include <WebServer.h>
#include <LittleFS.h>
#include <time.h>
#include <sys/time.h>
#include "local_page.h"
#include "static_accent.h"
WebServer deviceWeb(80);
bool storageReady=false,localRestartBle=false,localUploadAllowed=false,localExternal=false;
String localLayoutID="";
uint8_t* localIncoming=nullptr;
size_t localReceived=0;
time_t localClockMinute=0;
unsigned long localLastSaved=0;
String localUploadError,localMetadata="{\"tasks\":[]}";
struct WhitePlane {uint8_t operator[](unsigned)const{return 255;}};

// Local Wi-Fi direct access intentionally requires no shared access token.
void localReply(int code,const char* message){JsonDocument doc;doc[code==200?"message":"error"]=message;String json;serializeJson(doc,json);deviceWeb.sendHeader("Cache-Control","no-store");deviceWeb.send(code,"application/json; charset=utf-8",json);}
void localRelease(){free(localIncoming);localIncoming=nullptr;if(bleSuspended)localRestartBle=true;localUploadAllowed=false;}
void localSuspendBle(){if(NimBLEDevice::getInitialized()){bleSuspended=true;NimBLEDevice::deinit(true);}}
bool localReadSnapshot(bool loadPixels){
 File file=LittleFS.open("/local.dat","r");if(!file)return false;
 String metadata=file.readStringUntil('\n');if(metadata.length()>8192||file.available()!=PLANE_BYTES)return false;
 JsonDocument doc;if(deserializeJson(doc,metadata)||!doc["tasks"].is<JsonArray>())return false;
 localMetadata=metadata;localExternal=doc["external_layout"] | false;localLayoutID=doc["layout_id"] | "";if(loadPixels&&file.read(PartImage,PLANE_BYTES)!=PLANE_BYTES)return false;return true;
}
bool localSaveSnapshot(const String& metadata,const uint8_t* bytes){
 File file=LittleFS.open("/local.tmp","w");if(!file)return false;
 bool ok=file.print(metadata)==metadata.length()&&file.write((uint8_t)'\n')==1&&file.write(bytes,PLANE_BYTES)==PLANE_BYTES;
 file.flush();file.close();if(!ok){LittleFS.remove("/local.tmp");return false;}
 return LittleFS.rename("/local.tmp","/local.dat");
}
bool localValidateMetadata(const String& metadata){
 if(metadata.length()>8192)return false;
 JsonDocument doc;if(deserializeJson(doc,metadata)||!doc["tasks"].is<JsonArray>())return false;
 JsonArray tasks=doc["tasks"].as<JsonArray>();if(tasks.size()>8)return false;
 for(JsonVariant task:tasks){if(!task["title"].is<String>())return false;String title=task["title"].as<String>();if(!title.length()||title.length()>600)return false;if(!task["due"].isNull()&&(!task["due"].is<String>()||task["due"].as<String>().length()>40))return false;}
 return true;
}
void localPaint(const uint8_t* bytes,bool full,bool flexible=false,bool accent=false,unsigned accentStyle=0){
 SPI.beginTransaction(SPISettings(10000000,MSBFIRST,SPI_MODE0));
 if(full){
  // Static accent uses flash bytes only; no extra 48KB red allocation.
  for(size_t i=0;i<PLANE_BYTES;i++)localIncoming[i]=~localIncoming[i];
  EPD_Init();EPD_WhiteScreen_ALL(localIncoming,nullptr,nullptr,accent,accentStyle);EPD_DeepSleep();
  for(size_t i=0;i<PLANE_BYTES;i++)localIncoming[i]=~localIncoming[i];
 }else{
  bool started=false;WhitePlane white;
  auto update=[&](int x,int y,int w,int h){
   auto plan=planRegion(PartImage,bytes,white,x,y,w,h);if(!plan.changed)return;
   if(!started){EPD_Init_Differential();started=true;}
   EPD_Differential_Rect(PartImage,bytes,plan.x,plan.y,plan.right-plan.x,plan.bottom-plan.y);
   Serial.printf("Local region window=%d,%d %dx%d\n",plan.x,plan.y,plan.right-plan.x,plan.bottom-plan.y);
  };
  if(flexible){for(int y=0;y<480;y+=80)for(int x=0;x<800;x+=200){if(accent)withoutAccent(x,y,200,80,update);else update(x,y,200,80);}}
  else{for(const auto& area:REFRESH_REGIONS)update(area.x,area.y,area.w,area.h);}
  if(started)EPD_DeepSleep();
 }
 SPI.endTransaction();memcpy(PartImage,bytes,PLANE_BYTES);hasBase=true;
}
void localCommit(){
 if(localUploadError.length()||!localIncoming||localReceived!=PLANE_BYTES){localReply(400,localUploadError.length()?localUploadError.c_str():"画面数据不完整");localRelease();return;}
 String metadata=deviceWeb.arg("metadata");
 if(!localValidateMetadata(metadata)){localReply(400,"待办数据无效，最多八条");localRelease();return;}
 bool full=deviceWeb.arg("full")=="1";
 JsonDocument incomingMetadata;deserializeJson(incomingMetadata,metadata);bool incomingExternal=incomingMetadata["external_layout"] | false;String incomingLayout=incomingMetadata["layout_id"] | "";
 String accentVersion=incomingMetadata["accent_version"] | "";
 if(accentVersion.length()&&(!incomingExternal||accentVersion!="mojian-red-v2")){localReply(400,"红色布局版本不支持");localRelease();return;}
 bool incomingAccent=accentVersion=="mojian-red-v2";
 String styleName=incomingMetadata["accent_style"] | "";
 int styleIndex=accentStyleIndex(styleName.c_str());
 if(incomingAccent&&styleIndex<0){localReply(400,"红色样式不支持");localRelease();return;}
 JsonDocument oldDoc;deserializeJson(oldDoc,localMetadata);String oldAccent=oldDoc["accent_version"] | "";
 String oldStyle=oldDoc["accent_style"] | "";
 if(incomingMetadata["expected_content_key"].is<String>()){String expected=incomingMetadata["expected_content_key"].as<String>();String actual=oldDoc["content_key"] | "";if(expected!=actual){localReply(409,"设备内容已变化，请读取最新内容后重试");localRelease();return;}incomingMetadata.remove("expected_content_key");metadata="";serializeJson(incomingMetadata,metadata);}
 if(!full&&(accentVersion!=oldAccent||styleName!=oldStyle)){localReply(409,"固定红色变化需明确全刷一次");localRelease();return;}
 if(incomingAccent){for(unsigned i=8000;i<10400;i++)if(localIncoming[i]!=255){localReply(400,"固定红色保留区域不能写入黑色内容");localRelease();return;}}
 if(!full&&(incomingExternal!=localExternal||incomingLayout!=localLayoutID)){localReply(409,"布局已变化，请明确应用布局并全刷一次");localRelease();return;}
 if((!localMode||!hasBase)&&!full){localReply(409,"首次进入独立模式或重启后，需要明确选择一次全刷");localRelease();return;}
 JsonDocument previousMetadata;deserializeJson(previousMetadata,localMetadata);
 String contentKey=incomingMetadata["content_key"] | "";
 String previousKey=previousMetadata["content_key"] | "";
 overlayAutonomy(localIncoming,incomingLayout);
 bool shouldPersist=full||!incomingExternal||!contentKey.length()||contentKey!=previousKey||millis()-localLastSaved>=1800000UL;
 if(!storageReady||(shouldPersist&&!localSaveSnapshot(metadata,localIncoming))){localReply(503,"设备存储写入失败，原画面保持不变");localRelease();return;}
 if(shouldPersist)localLastSaved=millis();
 JsonDocument clockDoc;deserializeJson(clockDoc,metadata);long long seconds=clockDoc["epoch_seconds"] | 0LL;
 if(seconds>=1577836800LL&&seconds<4102444800LL){timeval value={(time_t)seconds,0};settimeofday(&value,nullptr);}
 localClockMinute=time(nullptr)/60;
 localPaint(localIncoming,full,true,incomingAccent,styleIndex<0?0:styleIndex);localMetadata=metadata;localExternal=incomingExternal;localLayoutID=incomingLayout;localMode=true;
 if(!LittleFS.exists("/local-mode")){File mode=LittleFS.open("/local-mode","w");mode.print("1");mode.close();}
 Serial.printf("Local standalone commit: full=%d bytes=%u\n",full,(unsigned)localReceived);
 localReply(200,"已保存并更新屏幕");localRelease();
}
void localUpload(){
 HTTPUpload& upload=deviceWeb.upload();
 if(upload.status==UPLOAD_FILE_START){
  localUploadError="";localReceived=0;localUploadAllowed=true;
  if(!localUploadAllowed)return;
  if(localIncoming){localUploadError="已有更新正在处理";return;}
  localSuspendBle();localIncoming=(uint8_t*)malloc(PLANE_BYTES);if(!localIncoming)localUploadError="设备画面内存不足，请重试";
 }else if(upload.status==UPLOAD_FILE_WRITE){
  if(!localUploadAllowed||localUploadError.length())return;
  if(!localIncoming||localReceived+upload.currentSize>PLANE_BYTES){localUploadError="画面大小不正确";return;}
  memcpy(localIncoming+localReceived,upload.buf,upload.currentSize);localReceived+=upload.currentSize;
 }else if(upload.status==UPLOAD_FILE_ABORTED){localUploadError="上传已中断，请重试";localRelease();}
}
void setupLocalPortal(){
 configTzTime("CST-8","pool.ntp.org","time.cloudflare.com");
 storageReady=LittleFS.begin(true);
 localMode=storageReady&&LittleFS.exists("/local-mode");
 if(localMode&&!localReadSnapshot(true)){localMode=false;localMetadata="{\"tasks\":[]}";}
 deviceWeb.on("/",HTTP_GET,[]{deviceWeb.sendHeader("Cache-Control","no-store");deviceWeb.send_P(200,"text/html; charset=utf-8",LOCAL_PAGE);});
 deviceWeb.on("/api/local/state",HTTP_GET,[]{
  JsonDocument doc;deserializeJson(doc,localMetadata);doc["local_mode"]=localMode;doc["needs_full"]=!localMode||!hasBase;doc["external_layout"]=localExternal;doc["layout_id"]=localLayoutID;doc["baseline_ready"]=hasBase;doc["storage_ready"]=storageReady;doc["accent_supported"]=true;doc["accent_version_supported"]="mojian-red-v2";doc["conditional_commit"]=true;doc["metadata_limit"]=8192;doc["provision_supported"]=true;doc["provision_open"]=provisionOpen();doc["autonomy_supported"]=true;doc["device_id"]=deviceIdentity();doc["discovery_host"]=deviceIdentity()+".local";
  String body;serializeJson(doc,body);deviceWeb.sendHeader("Cache-Control","no-store");deviceWeb.send(200,"application/json; charset=utf-8",body);
 });
 deviceWeb.on("/api/local/base",HTTP_GET,[]{
  deviceWeb.sendHeader("Cache-Control","no-store");deviceWeb.setContentLength(PLANE_BYTES);deviceWeb.send(200,"application/octet-stream","");
  if(hasBase||localMode)deviceWeb.sendContent((const char*)PartImage,PLANE_BYTES);
  else{uint8_t white[100];memset(white,255,sizeof white);for(int y=0;y<480;y++)deviceWeb.sendContent((const char*)white,100);}
 });
 deviceWeb.on("/api/local/commit",HTTP_POST,localCommit,localUpload);
 deviceWeb.on("/api/local/remote",HTTP_POST,[]{
  HTTPClient http;http.begin(String(TODO_SERVER)+"/api/display/refresh");authorize(http);http.addHeader("Content-Type","application/json");http.setTimeout(5000);int code=http.POST("{}");http.end();
  if(code!=200){localReply(503,"Mac服务不可用，继续保留独立模式");return;}
  legacyPolling=true;localMode=false;LittleFS.remove("/local-mode");hasBase=false;lastAttempt="";displayed="";localReply(200,"已切回Mac同步并请求一次全刷");
 });
 deviceWeb.onNotFound([]{localReply(404,"不存在");});deviceWeb.begin();
 Serial.printf("Local portal ready; storage=%d standalone=%d\n",storageReady,localMode);
}
void handleLocalPortal(){deviceWeb.handleClient();if(localRestartBle&&!autoFetching){localRestartBle=false;startBluetooth();}}

// Small pre-rendered Inter glyphs keep autonomous digits consistent with clients.
#include "autonomy_digits.h"
void localDigits(uint8_t* bitmap,const char* value,int x,int y,int scale){
 const uint8_t* glyphs;int w,h;
 switch(scale){case 2:glyphs=&AUTO_DIGITS_2[0][0];w=10;h=16;break;case 3:glyphs=&AUTO_DIGITS_3[0][0];w=16;h=24;break;case 4:glyphs=&AUTO_DIGITS_4[0][0];w=22;h=30;break;case 6:glyphs=&AUTO_DIGITS_6[0][0];w=34;h=46;break;default:return;}
 int stride=(w+7)/8;
 for(const char* c=value;*c;c++,x+=6*scale){int index=*c>='0'&&*c<='9'?*c-'0':*c==':'?10:*c=='-'?11:-1;if(index<0)continue;
  for(int yy=0;yy<h;yy++)for(int xx=0;xx<w;xx++)if(!(glyphs[index*stride*h+yy*stride+xx/8]&(128>>(xx%8)))){int px=x+xx,py=y+yy;if(px>=0&&px<800&&py>=0&&py<480)bitmap[py*100+px/8]&=~(128>>(px%8));}
 }
}
void updateLocalClock(){
 if(!localMode||!hasBase||localIncoming||localExternal)return;
 time_t stamp=time(nullptr);if(stamp<1577836800||stamp/60==localClockMinute)return;
 localSuspendBle();localIncoming=(uint8_t*)malloc(PLANE_BYTES);if(!localIncoming){localRelease();return;}
 memcpy(localIncoming,PartImage,PLANE_BYTES);
 for(int y=0;y<104;y++)memset(localIncoming+y*100+3,255,26);
 tm current;localtime_r(&stamp,&current);char clock[6],date[11];strftime(clock,sizeof(clock),"%H:%M",&current);strftime(date,sizeof(date),"%Y-%m-%d",&current);
 localDigits(localIncoming,clock,24,12,6);localDigits(localIncoming,date,26,76,2);
 localPaint(localIncoming,false);localClockMinute=stamp/60;localRelease();Serial.println("Standalone clock updated");
}
