#pragma once
#include <WebServer.h>
#include <LittleFS.h>
#include <time.h>
#include <sys/time.h>
#include "local_page.h"
#include "static_accent.h"
#include "paint_transaction.h"
#include "frame_borrow.h"
#include "local_commit_policy.h"
WebServer deviceWeb(80);
bool storageReady=false,localRestartBle=false,localUploadAllowed=false,localExternal=false;
bool localSnapshotError=false;
unsigned long localClockRetryAt=0;
String localLayoutID="";
PagedPlane localFrameStorage;
PagedPlane* localIncoming=nullptr;
size_t localReceived=0;
uint32_t localUploadActivity=0;
time_t localClockMinute=0;
unsigned long localLastSaved=0;
int localUploadStatus=400;
String localUploadError,localMetadata="{\"tasks\":[]}";
PaintTransaction localPaintTransaction;
TaskHandle_t localDisplayTask=nullptr;
enum LocalPaintPurpose {PaintCommit,PaintAutonomy,PaintClock};
struct LocalPaintJob {
 bool full=false,flexible=false,accent=false,baseline=false,fault=false;unsigned style=0,timeouts=0;
 LocalPaintPurpose purpose=PaintCommit;time_t minute=0;String metadata,layout;bool external=false;
} localPaintJob;
String localTransactionID;unsigned localTransactionStatus=0;uint32_t localTransactionSequence=0;
void finishAutonomousPaint(time_t minute,bool success);
bool localDisplayBusy(){return localPaintTransaction.active();}
bool localBaselineReady(){return localDisplayBusy()?localPaintJob.baseline:hasBase;}
struct WhitePlane {uint8_t operator[](unsigned)const{return 255;}};

// Local Wi-Fi direct access intentionally requires no shared access token.
void localReply(int code,const char* message){JsonDocument doc;doc[code==200?"message":"error"]=message;String json;serializeJson(doc,json);deviceWeb.sendHeader("Cache-Control","no-store");deviceWeb.send(code,"application/json; charset=utf-8",json);}
void localRelease(){localFrameStorage.release();localIncoming=nullptr;if(bleSuspended)localRestartBle=true;localUploadAllowed=false;}
void localSuspendBle(){if(NimBLEDevice::getInitialized()){bleSuspended=true;NimBLEDevice::deinit(true);}}
bool localAcquireFrame(){return acquireBorrowedFrame([]{localSuspendBle();},[]{localIncoming=localFrameStorage.allocate()?&localFrameStorage:nullptr;return localIncoming;},[]{localRelease();})!=nullptr;}
bool localReadSnapshot(bool loadPixels){
 File file=LittleFS.open("/local.dat","r");if(!file)return false;
 // Bound the line read before parsing: metadata line + '\n' + 48000-byte frame.
 size_t minimum=PLANE_BYTES+1,maximum=minimum+8192;
 if(file.size()<minimum||file.size()>maximum)return false;
 String metadata=file.readStringUntil('\n');if(metadata.length()>8192||file.available()!=PLANE_BYTES)return false;
 JsonDocument doc;if(deserializeJson(doc,metadata)||!doc["tasks"].is<JsonArray>())return false;
 localMetadata=metadata;localExternal=doc["external_layout"] | false;localLayoutID=doc["layout_id"] | "";if(loadPixels&&file.read(PartImage,PLANE_BYTES)!=PLANE_BYTES)return false;return true;
}
bool localSaveSnapshot(const String& metadata,const PagedPlane& bytes){
 File file=LittleFS.open("/local.tmp","w");if(!file)return false;
 bool ok=file.print(metadata)==metadata.length()&&file.write((uint8_t)'\n')==1;
 for(auto page:bytes.pages)if(ok)ok=file.write(page,PagedPlane::PAGE_BYTES)==PagedPlane::PAGE_BYTES;
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
bool localPaint(const PagedPlane& bytes,bool full,bool flexible=false,bool accent=false,unsigned accentStyle=0){
 if(displayGuard.failed&&!full){hasBase=false;return false;}
 if(full)displayGuard.reset();
#ifdef MOJIAN_EXPERIMENT_GX_REFERENCE
 bool referenceOkay=true;
 if(full)SPI.beginTransaction(SPISettings(10000000,MSBFIRST,SPI_MODE0));
#else
 SPI.beginTransaction(SPISettings(10000000,MSBFIRST,SPI_MODE0));
#endif
 if(full){
  // Static accent uses flash bytes only; no extra 48KB red allocation.
  for(size_t i=0;i<PLANE_BYTES;i++)(*localIncoming)[i]=~(*localIncoming)[i];
  EPD_Init();EPD_WhiteScreen_ALL(nullptr,nullptr,nullptr,accent,accentStyle,localIncoming);EPD_DeepSleep();
  for(size_t i=0;i<PLANE_BYTES;i++)(*localIncoming)[i]=~(*localIncoming)[i];
 }else{
  bool started=false;WhitePlane white;
  auto update=[&](int x,int y,int w,int h){
   if(displayGuard.failed)return;
#ifdef MOJIAN_EXPERIMENT_GX_REFERENCE
   if(!referenceOkay)return;
#endif
   auto plan=planRegion(PartImage,bytes,white,x,y,w,h);if(!plan.changed)return;
   if(!started){
#ifdef MOJIAN_EXPERIMENT_GX_REFERENCE
    referencePartialBegin(PartImage);
#else
    EPD_Init_Differential();
#endif
    started=true;
   }
#ifdef MOJIAN_EXPERIMENT_GX_REFERENCE
   if(!referencePartialRect(PartImage,bytes,plan.x,plan.y,plan.right-plan.x,plan.bottom-plan.y,accent)){referenceOkay=false;return;}
#else
   EPD_Differential_Rect(PartImage,bytes,plan.x,plan.y,plan.right-plan.x,plan.bottom-plan.y);
#endif
   Serial.printf("Local region window=%d,%d %dx%d\n",plan.x,plan.y,plan.right-plan.x,plan.bottom-plan.y);
  };
  if(flexible){for(int y=0;y<480;y+=80)for(int x=0;x<800;x+=200){if(accent)withoutAccent(x,y,200,80,update);else update(x,y,200,80);}}
  else{for(const auto& area:REFRESH_REGIONS){if(accent)withoutAccent(area.x,area.y,area.w,area.h,update);else update(area.x,area.y,area.w,area.h);}}
  if(started){
#ifdef MOJIAN_EXPERIMENT_GX_REFERENCE
   referencePartialEnd();
#else
   EPD_DeepSleep();
#endif
  }
 }
#ifdef MOJIAN_EXPERIMENT_GX_REFERENCE
 if(full)SPI.endTransaction();
 if(!referenceOkay){hasBase=false;return false;}
#else
 SPI.endTransaction();
#endif
 if(displayGuard.failed){hasBase=false;return false;}
 bytes.copyTo(PartImage);hasBase=true;return true;
}
// The worker only owns SPI and the two frame buffers. Metadata, persistence,
// BLE restoration and transaction receipts are finalized on the main loop.
void localPaintWorker(void*){
 for(;;){
  ulTaskNotifyTake(pdTRUE,portMAX_DELAY);
  bool success=localPaint(*localIncoming,localPaintJob.full,localPaintJob.flexible,localPaintJob.accent,localPaintJob.style);
  localPaintTransaction.finish(success);
 }
}
bool prepareLocalPaint(){
 // Reserve the persistent worker before committing a snapshot. Allocation
 // failure cannot leave a new disk snapshot behind an old public state.
 return localDisplayTask||xTaskCreate(localPaintWorker,"mojian-display",4096,nullptr,1,&localDisplayTask)==pdPASS;
}
bool startLocalPaint(LocalPaintPurpose purpose,bool full,bool flexible,bool accent,unsigned style,time_t minute=0){
 if(localDisplayBusy()||!prepareLocalPaint())return false;
 localPaintJob.full=full;localPaintJob.flexible=flexible;localPaintJob.accent=accent;localPaintJob.style=style;localPaintJob.purpose=purpose;localPaintJob.minute=minute;
 localPaintJob.baseline=hasBase;localPaintJob.fault=displayGuard.failed;localPaintJob.timeouts=displayGuard.timeouts;
 if(!localPaintTransaction.begin())return false;
 // An upload watchdog must never free the frame lent to the display worker.
 localUploadAllowed=false;
 xTaskNotifyGive(localDisplayTask);
 return true;
}
void finishLocalPaint(){
 unsigned result=localPaintTransaction.result();if(result!=PaintTransaction::Completed&&result!=PaintTransaction::Failed)return;
 bool success=result==PaintTransaction::Completed;
 if(localPaintJob.purpose==PaintCommit){
  localMetadata=localPaintJob.metadata;localExternal=localPaintJob.external;localLayoutID=localPaintJob.layout;localMode=true;localSnapshotError=false;
  if(!LittleFS.exists("/local-mode")){File mode=LittleFS.open("/local-mode","w");mode.print("1");mode.close();}
  localTransactionStatus=success?2:3;
 }else if(localPaintJob.purpose==PaintAutonomy)finishAutonomousPaint(localPaintJob.minute,success);
 else if(success)localClockMinute=localPaintJob.minute;
 localRelease();localPaintJob.metadata="";localPaintJob.layout="";localPaintTransaction.release();
}
void localCommit(){
 if(localDisplayBusy()){localReply(423,"屏幕正在更新，请稍后重试");return;}

 if(localUploadError.length()||!localIncoming||localReceived!=PLANE_BYTES){localReply(localUploadError.length()?localUploadStatus:400,localUploadError.length()?localUploadError.c_str():"画面数据不完整");localRelease();return;}
 String metadata=deviceWeb.arg("metadata");
 if(!localValidateMetadata(metadata)){localReply(400,"待办数据无效，最多八条");localRelease();return;}
 bool full=deviceWeb.arg("full")=="1";
 JsonDocument incomingMetadata;deserializeJson(incomingMetadata,metadata);bool incomingExternal=incomingMetadata["external_layout"] | false;String incomingLayout=incomingMetadata["layout_id"] | "";
 String accentVersion=incomingMetadata["accent_version"] | "";
 const char* accentError=localAccentPolicy(incomingExternal,incomingLayout.c_str(),accentVersion.c_str());
 if(accentError){localReply(400,accentError);localRelease();return;}
 bool incomingAccent=accentVersion=="mojian-red-v2";
 String styleName=incomingMetadata["accent_style"] | "";
 int styleIndex=accentStyleIndex(styleName.c_str());
 if(incomingAccent&&styleIndex<0){localReply(400,"红色样式不支持");localRelease();return;}
 JsonDocument oldDoc;deserializeJson(oldDoc,localMetadata);String oldAccent=oldDoc["accent_version"] | "";
 String oldStyle=oldDoc["accent_style"] | "";
 if(incomingMetadata["expected_content_key"].is<String>()){String expected=incomingMetadata["expected_content_key"].as<String>();String actual=oldDoc["content_key"] | "";if(expected!=actual){localReply(409,"设备内容已变化，请读取最新内容后重试");localRelease();return;}incomingMetadata.remove("expected_content_key");metadata="";serializeJson(incomingMetadata,metadata);}
 if(!full&&(accentVersion!=oldAccent||styleName!=oldStyle)){localReply(409,"固定红色变化需明确全刷一次");localRelease();return;}
 if(incomingAccent){for(unsigned i=8000;i<10400;i++)if((*localIncoming)[i]!=255){localReply(400,"固定红色保留区域不能写入黑色内容");localRelease();return;}}
 if(!full&&(incomingExternal!=localExternal||incomingLayout!=localLayoutID)){localReply(409,"布局已变化，请明确应用布局并全刷一次");localRelease();return;}
 if((!localMode||!hasBase)&&!full){localReply(409,"首次进入独立模式或重启后，需要明确选择一次全刷");localRelease();return;}
 JsonDocument previousMetadata;deserializeJson(previousMetadata,localMetadata);
 String contentKey=incomingMetadata["content_key"] | "";
 String previousKey=previousMetadata["content_key"] | "";
 if(deviceWeb.arg("async")=="1"&&!prepareLocalPaint()){localReply(503,"显示任务内存不足，原内容保留，请稍后重试");localRelease();return;}
 // Apply client time before drawing so an autonomy clock in this frame uses it.
 JsonDocument clockDoc;deserializeJson(clockDoc,metadata);long long seconds=clockDoc["epoch_seconds"] | 0LL;
 if(seconds>=1577836800LL&&seconds<4102444800LL){timeval value={(time_t)seconds,0};settimeofday(&value,nullptr);}
 localClockMinute=time(nullptr)/60;
 overlayAutonomy(*localIncoming,incomingLayout);
 bool shouldPersist=full||!incomingExternal||!contentKey.length()||contentKey!=previousKey||millis()-localLastSaved>=1800000UL;
 if(!storageReady||(shouldPersist&&!localSaveSnapshot(metadata,*localIncoming))){localReply(503,"设备存储写入失败，原画面保持不变");localRelease();return;}
 if(shouldPersist)localLastSaved=millis();
 if(deviceWeb.arg("async")=="1"){
  localPaintJob.metadata=metadata;localPaintJob.external=incomingExternal;localPaintJob.layout=incomingLayout;
  if(!startLocalPaint(PaintCommit,full,true,incomingAccent,styleIndex<0?0:styleIndex)){localReply(503,"显示任务内存不足，内容已保存，请重试");localRelease();return;}
  char id[32];snprintf(id,sizeof id,"%08lx-%08lx",(unsigned long)esp_random(),(unsigned long)++localTransactionSequence);localTransactionID=id;localTransactionStatus=1;
  JsonDocument reply;reply["transaction_id"]=localTransactionID;reply["status"]="pending";String text;serializeJson(reply,text);deviceWeb.sendHeader("Cache-Control","no-store");deviceWeb.send(202,"application/json",text);return;
 }
 // Compatibility for clients predating async_commit; success still means the
 // synchronous draw finished, never merely that the request was accepted.
 bool painted=localPaint(*localIncoming,full,true,incomingAccent,styleIndex<0?0:styleIndex);localMetadata=metadata;localExternal=incomingExternal;localLayoutID=incomingLayout;localMode=true;localSnapshotError=false;
 if(!LittleFS.exists("/local-mode")){File mode=LittleFS.open("/local-mode","w");mode.print("1");mode.close();}
 Serial.printf("Local standalone commit: full=%d bytes=%u\n",full,(unsigned)localReceived);
 localReply(painted?200:503,painted?"已保存并更新屏幕":"内容已保存，但屏幕忙碌超时；检查供电与排线后请明确应用布局，设备仍可联网");localRelease();
}
void localUpload(){
 HTTPUpload& upload=deviceWeb.upload();
 if(upload.status==UPLOAD_FILE_START){
  localUploadError="";localUploadStatus=400;localReceived=0;localUploadAllowed=false;localUploadActivity=millis();
  if(localIncoming||autoFetching||provisionAttempt){localUploadStatus=423;localUploadError="已有更新正在处理，请稍后重试";return;}
  localUploadAllowed=true;
  if(!localAcquireFrame()){localUploadStatus=503;localUploadError="设备画面内存不足，请重试";}
 }else if(upload.status==UPLOAD_FILE_WRITE){
  if(!localUploadAllowed||localUploadError.length())return;
  if(!localIncoming||localReceived+upload.currentSize>PLANE_BYTES){localUploadError="画面大小不正确";return;}
  localUploadActivity=millis();localIncoming->write(localReceived,upload.buf,upload.currentSize);localReceived+=upload.currentSize;
 }else if(upload.status==UPLOAD_FILE_ABORTED){localUploadError="上传已中断，请重试";if(!localDisplayBusy())localRelease();}
}
void setupLocalPortal(){
 configTzTime("CST-8","pool.ntp.org","time.cloudflare.com");
 // A mount failure must not silently format the user snapshot.
 storageReady=LittleFS.begin(false);
 localMode=storageReady&&LittleFS.exists("/local-mode");
 localSnapshotError=false;
 if(localMode&&!localReadSnapshot(true)){localMode=false;localMetadata="{\"tasks\":[]}";localSnapshotError=true;}
 // No local-mode snapshot means the legacy Python poll is the active path.
 legacyPolling=!localMode;
 deviceWeb.on("/",HTTP_GET,[]{deviceWeb.sendHeader("Cache-Control","no-store");deviceWeb.send_P(200,"text/html; charset=utf-8",LOCAL_PAGE);});
 deviceWeb.on("/api/local/state",HTTP_GET,[]{
  if(!storageReady){localReply(503,"设备存储不可用，原数据未格式化；请检查设备，不要用空清单覆盖本机记录");return;}
  if(localSnapshotError){localReply(503,"设备本地快照不可读，未发布空清单；请明确重新应用布局恢复");return;}
  JsonDocument doc;deserializeJson(doc,localMetadata);doc["local_mode"]=localMode;doc["needs_full"]=!localMode||!localBaselineReady();doc["external_layout"]=localExternal;doc["layout_id"]=localLayoutID;doc["baseline_ready"]=localBaselineReady();doc["display_busy"]=localDisplayBusy();doc["async_commit"]=true;doc["storage_ready"]=storageReady;doc["accent_supported"]=true;doc["accent_version_supported"]="mojian-red-v2";doc["conditional_commit"]=true;doc["metadata_limit"]=8192;doc["provision_supported"]=true;doc["provision_open"]=provisionOpen();doc["autonomy_supported"]=true;doc["device_id"]=deviceIdentity();doc["discovery_host"]=deviceIdentity()+".local";
  String body;serializeJson(doc,body);deviceWeb.sendHeader("Cache-Control","no-store");deviceWeb.send(200,"application/json; charset=utf-8",body);
 });
 deviceWeb.on("/api/local/health",HTTP_GET,[]{
  JsonDocument j;j["device_id"]=deviceIdentity();j["firmware_revision"]="display-wait-2026-11-07";j["uptime_seconds"]=(uint64_t)(esp_timer_get_time()/1000000ULL);j["storage_ready"]=storageReady;j["snapshot_error"]=localSnapshotError;j["uptime_ms"]=(uint32_t)millis();j["reset_reason"]=(int)esp_reset_reason();j["wifi_connected"]=WiFi.status()==WL_CONNECTED;j["ip"]=WiFi.localIP().toString();j["rssi"]=WiFi.status()==WL_CONNECTED?WiFi.RSSI():0;j["disconnects"]=networkDisconnects.load();j["last_disconnect_reason"]=networkLastReason.load();j["network_generation"]=networkGeneration.load();j["reconnects"]=networkReconnects;j["radio_restarts"]=networkRadioRestarts;j["heap_free"]=ESP.getFreeHeap();j["heap_min"]=ESP.getMinFreeHeap();j["heap_largest"]=ESP.getMaxAllocHeap();bool drawing=localDisplayBusy();j["display_busy"]=drawing;j["display_fault"]=drawing?localPaintJob.fault:displayGuard.failed;j["display_timeouts"]=drawing?localPaintJob.timeouts:displayGuard.timeouts;j["baseline_ready"]=localBaselineReady();if(!drawing){j["shutdown_attempted"]=displayGuard.shutdownAttempted;j["shutdown_confirmed"]=displayGuard.shutdownConfirmed;}
#ifdef MOJIAN_EXPERIMENT_GX_REFERENCE
  j["firmware_revision"]="reference-stride-2026-11-08";
  j["display_experiment"]="gxepd2-1.6.9-reference";
  j["display_reference_commit"]="de82887e77a78528ea386e68bba2cb0291d2c319";
  j["display_partial_spi_hz"]=10000000;
#endif
#ifdef MOJIAN_EXPERIMENT_GX_FULL_TEMP
  j["firmware_revision"]="gx-full-temp-2026-11-08";
  j["display_experiment"]="gxepd2-full-temperature";
#endif
#ifdef MOJIAN_EXPERIMENT_GX_FULL_CDI
  j["firmware_revision"]="gx-full-cdi-2026-11-08";
  j["display_experiment"]="gxepd2-full-cdi";
#endif
#ifdef MOJIAN_EXPERIMENT_BW_SLEEP
  j["display_experiment"]="bw-sleep-no-vcom-rewrite-2026-10-31";
#endif
#ifdef MOJIAN_EXPERIMENT_BW_INIT
  j["display_experiment"]="bw-corrected-init-2026-10-31";
#endif
  // Independent atomic samples; not an atomic transaction snapshot or receipt.
  j["display_refresh_commands"]=displayTelemetry.refreshCommands.load();j["display_refresh_completed"]=displayTelemetry.refreshCompleted.load();j["display_differential_windows"]=displayTelemetry.differentialWindows.load();j["display_last_refresh_wait_ms"]=displayTelemetry.lastRefreshWaitMs.load();j["display_normal_poweroff_waits"]=displayTelemetry.powerOffWaits.load();j["display_last_poweroff_wait_ms"]=displayTelemetry.lastPowerOffWaitMs.load();j["display_last_poweroff_busy_ready"]=displayTelemetry.lastPowerOffBusyReady.load();j["display_last_poweroff_busy_seen"]=displayTelemetry.lastPowerOffBusySeen.load();
  j["frame_page_bytes"]=PagedPlane::PAGE_BYTES;j["frame_page_count"]=PagedPlane::PAGE_COUNT;j["frame_buffer_active"]=localIncoming!=nullptr;
  j["baseline_reason"]=localBaselineReady()?"ready":(!storageReady?"storage_unavailable":((drawing?localPaintJob.fault:displayGuard.failed)?"display_fault":(localMode?"restart_requires_explicit_refresh":"layout_not_applied")));
  String body;serializeJson(j,body);deviceWeb.sendHeader("Cache-Control","no-store");deviceWeb.send(200,"application/json",body);
 });
 deviceWeb.on("/api/local/transaction",HTTP_GET,[]{
  if(!localTransactionStatus||deviceWeb.arg("id")!=localTransactionID){localReply(404,"显示事务不存在，请读取设备当前状态");return;}
  JsonDocument j;j["transaction_id"]=localTransactionID;j["status"]=localTransactionStatus==1?"pending":localTransactionStatus==2?"completed":"failed";if(localTransactionStatus==3)j["error"]="内容已保存，但屏幕更新失败；检查硬件后请明确应用布局";String text;serializeJson(j,text);deviceWeb.sendHeader("Cache-Control","no-store");deviceWeb.send(200,"application/json",text);
 });
 deviceWeb.on("/api/local/base",HTTP_GET,[]{
  if(localDisplayBusy()){localReply(423,"屏幕正在更新，请稍后读取画面");return;}
  deviceWeb.sendHeader("Cache-Control","no-store");deviceWeb.setContentLength(PLANE_BYTES);deviceWeb.send(200,"application/octet-stream","");
  if(hasBase||localMode)deviceWeb.sendContent((const char*)PartImage,PLANE_BYTES);
  else{uint8_t white[100];memset(white,255,sizeof white);for(int y=0;y<480;y++)deviceWeb.sendContent((const char*)white,100);}
 });
 deviceWeb.on("/api/local/commit",HTTP_POST,localCommit,localUpload);
 deviceWeb.on("/api/local/remote",HTTP_POST,[]{
  if(localDisplayBusy()){localReply(423,"屏幕正在更新，请稍后切换");return;}
  HTTPClient http;http.begin(String(TODO_SERVER)+"/api/display/refresh");authorize(http);http.addHeader("Content-Type","application/json");http.setTimeout(5000);int code=http.POST("{}");http.end();
  if(code!=200){localReply(503,"Mac服务不可用，继续保留独立模式");return;}
  legacyPolling=true;localMode=false;localSnapshotError=false;LittleFS.remove("/local-mode");hasBase=false;lastAttempt="";displayed="";localReply(200,"已切回Mac同步并请求一次全刷");
 });
 deviceWeb.onNotFound([]{localReply(404,"不存在");});deviceWeb.begin();
 Serial.printf("Local portal ready; storage=%d standalone=%d\n",storageReady,localMode);
}
void handleLocalPortal(){finishLocalPaint();deviceWeb.handleClient();if(localIncoming&&!localDisplayBusy()&&uint32_t(millis()-localUploadActivity)>=30000U){deviceWeb.close();deviceWeb.begin();localRelease();Serial.println("Abandoned upload released");}if(localRestartBle&&!autoFetching&&!localIncoming){localRestartBle=false;startBluetooth();}}

// Small pre-rendered Inter glyphs keep autonomous digits consistent with clients.
#include "autonomy_digits.h"
template<class Plane> void localDigits(Plane& bitmap,const char* value,int x,int y,int scale){
 const uint8_t* glyphs;int w,h;
 switch(scale){case 2:glyphs=&AUTO_DIGITS_2[0][0];w=10;h=16;break;case 3:glyphs=&AUTO_DIGITS_3[0][0];w=16;h=24;break;case 4:glyphs=&AUTO_DIGITS_4[0][0];w=22;h=30;break;case 6:glyphs=&AUTO_DIGITS_6[0][0];w=34;h=46;break;default:return;}
 int stride=(w+7)/8;
 for(const char* c=value;*c;c++,x+=6*scale){int index=*c>='0'&&*c<='9'?*c-'0':*c==':'?10:*c=='-'?11:-1;if(index<0)continue;
  for(int yy=0;yy<h;yy++)for(int xx=0;xx<w;xx++)if(!(glyphs[index*stride*h+yy*stride+xx/8]&(128>>(xx%8)))){int px=x+xx,py=y+yy;if(px>=0&&px<800&&py>=0&&py<480)bitmap[py*100+px/8]&=~(128>>(px%8));}
 }
}
void updateLocalClock(){
 if(localDisplayBusy()||displayGuard.failed||!localMode||!hasBase||localIncoming||localExternal)return;
 if(localClockRetryAt&&(int32_t)(millis()-localClockRetryAt)<0)return;
 time_t stamp=time(nullptr);if(stamp<1577836800||stamp/60==localClockMinute)return;
 if(!localAcquireFrame()){localClockRetryAt=millis()+5000;return;}
 localIncoming->write(0,PartImage,PLANE_BYTES);
 for(int y=0;y<104;y++)for(int col=3;col<29;col++)(*localIncoming)[y*100+col]=255;
 tm current;localtime_r(&stamp,&current);char clock[6],date[11];strftime(clock,sizeof(clock),"%H:%M",&current);strftime(date,sizeof(date),"%Y-%m-%d",&current);
 localDigits(*localIncoming,clock,24,12,6);localDigits(*localIncoming,date,26,76,2);
 if(!startLocalPaint(PaintClock,false,false,false,0,stamp/60)){localRelease();localClockRetryAt=millis()+5000;}
 else localClockRetryAt=0;
}
