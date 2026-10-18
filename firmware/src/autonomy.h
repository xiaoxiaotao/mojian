#pragma once
#include <WiFiClientSecure.h>
#include "mbedtls/base64.h"
#include "autonomy_font.h"
#include "autonomy_geometry.h"
#include "weather_roots.h"
#include "weather_transport.h"
struct AutoWeather {bool ok=false;float temperature=0;int code=0;time_t fetched=0;int httpStatus=0;int tlsError=0;uint32_t address=0;};
bool autoEnabled=false,autoFetching=false,autoResultReady=false;
double autoLatitude=31.3,autoLongitude=120.58;
uint8_t autoCity[320];
AutoWeather autoCache,autoResult;
portMUX_TYPE autoMux=portMUX_INITIALIZER_UNLOCKED;
unsigned long autoNextFetch=0;
time_t autoMinute=-1;
String autoError="";int autoLastHTTP=0,autoLastTLS=0;uint32_t autoLastAddress=0;
void autoClear(uint8_t* bytes,int x,int y,int w,int h){for(int yy=y;yy<y+h;yy++)for(int xx=x;xx<x+w;xx++)autoPixel(bytes,xx,yy,true);}
void autoGlyph(uint8_t* bytes,const String& text,int x,int y){for(unsigned offset=0;offset<text.length();){int length=(uint8_t)text[offset]>=0xe0?3:1;String glyph=text.substring(offset,offset+length);const char* match=strstr(AUTO_CHARS,glyph.c_str());if(match){unsigned index=0;for(const char* p=AUTO_CHARS;p<match;p++)if(((uint8_t)*p&0xc0)!=0x80)index++;for(int row=0;row<20;row++)for(int col=0;col<16;col++)if(!(AUTO_GLYPHS[index][row*2+col/8]&(128>>(col%8))))autoPixel(bytes,x+col,y+row,false);}x+=16;offset+=length;}}
String autoWeatherText(int code){if(code==0)return "晴";if(code<=3)return "多云";if(code<=48)return "雾";if(code<=67)return "雨";if(code<=77)return "雪";if(code<=82)return "阵雨";return "雷雨";}
void overlayAutonomy(uint8_t* bytes,const String& layout){
 if(!autoEnabled)return;time_t stamp=time(nullptr);if(stamp<1577836800LL)return;tm local;localtime_r(&stamp,&local);char clock[6];strftime(clock,sizeof clock,"%H:%M",&local);
 bool calendar=layout.startsWith("mac.calendar."),phone=layout.endsWith(".phone");AutoRect clockArea=autoClockRect(calendar,phone);int x=clockArea.x,y=clockArea.y,scale=calendar&&!phone?3:6;
 autoClear(bytes,x,y,clockArea.w,clockArea.h);localDigits(bytes,clock,x,y+10,scale);
 if(!autoCache.ok)return;AutoRect weatherArea=autoWeatherRect(calendar,phone);int wx=weatherArea.x,wy=weatherArea.y,ww=weatherArea.w;
 autoClear(bytes,wx,wy,ww,66);for(int row=0;row<20;row++)for(int col=0;col<128;col++)if(!(autoCity[row*16+col/8]&(128>>(col%8))))autoPixel(bytes,wx+col,wy+row,false);
 autoGlyph(bytes,stamp-autoCache.fetched>3600?"旧天气":autoWeatherText(autoCache.code),wx+140,wy);
 char temperature[8];snprintf(temperature,sizeof temperature,"%d",(int)round(autoCache.temperature));localDigits(bytes,temperature,wx,wy+30,4);autoGlyph(bytes,"℃",wx+strlen(temperature)*24,wy+30);
 autoGlyph(bytes,"更新",wx+112,wy+23);tm fetched;localtime_r(&autoCache.fetched,&fetched);char at[6];strftime(at,sizeof at,"%H:%M",&fetched);localDigits(bytes,at,wx+112,wy+49,2);
}
struct AutoJob {double latitude,longitude;};
void fetchAutoWeather(void* context){AutoJob job=*(AutoJob*)context;delete (AutoJob*)context;AutoWeather result;{
 WeatherTLS secure;secure.setCACert(WEATHER_ROOTS);secure.setHandshakeTimeout(20);HTTPClient http;String url="https://api.open-meteo.com/v1/forecast?latitude="+String(job.latitude,5)+"&longitude="+String(job.longitude,5)+"&current=temperature_2m,weather_code&timezone=Asia%2FShanghai";http.setConnectTimeout(15000);http.setTimeout(15000);http.setFollowRedirects(HTTPC_DISABLE_FOLLOW_REDIRECTS);
 int response=http.begin(secure,url)?http.GET():-100;result.httpStatus=response;result.address=(uint32_t)secure.resolved;char tlsMessage[96];result.tlsError=secure.lastError(tlsMessage,sizeof tlsMessage);if(result.tlsError>=0)result.tlsError=0;
 if(response==200&&http.getSize()<8192){JsonDocument j;String body=http.getString();if(body.length()<8192&&!deserializeJson(j,body)&&j["current"]["temperature_2m"].is<float>()&&j["current"]["weather_code"].is<int>()){float t=j["current"]["temperature_2m"];int code=j["current"]["weather_code"];if(isfinite(t)&&t>=-100&&t<=80&&code>=0&&code<=99){result.ok=true;result.temperature=t;result.code=code;result.fetched=time(nullptr);}}}http.end();}
 Serial.printf("Autonomous weather: http=%d tls=%d ok=%d heap=%u\n",result.httpStatus,result.tlsError,result.ok,ESP.getFreeHeap());
 portENTER_CRITICAL(&autoMux);autoResult=result;autoResultReady=true;portEXIT_CRITICAL(&autoMux);vTaskDelete(nullptr);
}
bool autoSave(){JsonDocument j;j["enabled"]=autoEnabled;j["latitude"]=autoLatitude;j["longitude"]=autoLongitude;unsigned char b64[440];size_t written=0;mbedtls_base64_encode(b64,sizeof b64,&written,autoCity,sizeof autoCity);j["city_bitmap"]=String((char*)b64,written);if(autoCache.ok){j["temperature"]=autoCache.temperature;j["code"]=autoCache.code;j["fetched"]=(long long)autoCache.fetched;}File f=LittleFS.open("/autonomy.tmp","w");if(f){bool ok=serializeJson(j,f)>0;f.flush();f.close();return ok&&LittleFS.rename("/autonomy.tmp","/autonomy.json");}return false;}
void setupAutonomy(){memset(autoCity,255,sizeof autoCity);File f=LittleFS.open("/autonomy.json","r");if(f){JsonDocument j;if(!deserializeJson(j,f)){autoEnabled=j["enabled"]|false;autoLatitude=j["latitude"]|31.3;autoLongitude=j["longitude"]|120.58;String city=j["city_bitmap"]|"";size_t length=0;mbedtls_base64_decode(autoCity,sizeof autoCity,&length,(const unsigned char*)city.c_str(),city.length());if(j["fetched"].is<long long>()){autoCache.ok=true;autoCache.temperature=j["temperature"]|0.f;autoCache.code=j["code"]|0;autoCache.fetched=(time_t)j["fetched"].as<long long>();}}f.close();}
 deviceWeb.on("/api/local/autonomy",HTTP_GET,[]{JsonDocument j;j["supported"]=true;j["enabled"]=autoEnabled;j["clock_ready"]=time(nullptr)>1577836800LL;j["baseline_ready"]=hasBase;j["weather_available"]=autoCache.ok;j["weather_fetched"]=(long long)autoCache.fetched;j["fetching"]=autoFetching;j["error"]=autoError;j["weather_http"]=autoLastHTTP;j["weather_tls"]=autoLastTLS;j["weather_address"]=IPAddress(autoLastAddress).toString();j["epoch_seconds"]=(long long)time(nullptr);String text;serializeJson(j,text);deviceWeb.sendHeader("Cache-Control","no-store");deviceWeb.send(200,"application/json",text);});
 deviceWeb.on("/api/local/autonomy",HTTP_POST,[]{if(deviceWeb.arg("plain").length()>2048){localReply(400,"配置过长");return;}JsonDocument j;if(deserializeJson(j,deviceWeb.arg("plain"))||!j["enabled"].is<bool>()){localReply(400,"自主更新配置无效");return;}bool enabled=j["enabled"];bool priorEnabled=autoEnabled;double priorLat=autoLatitude,priorLon=autoLongitude;uint8_t priorCity[320];memcpy(priorCity,autoCity,320);AutoWeather priorCache=autoCache;if(enabled){double latitude=j["latitude"]|999.,longitude=j["longitude"]|999.;String city=j["city_bitmap"]|"";uint8_t bitmap[320];size_t length=0;if(!isfinite(latitude)||latitude< -90||latitude>90||!isfinite(longitude)||longitude< -180||longitude>180||mbedtls_base64_decode(bitmap,sizeof bitmap,&length,(const unsigned char*)city.c_str(),city.length())||length!=320){localReply(400,"天气位置或城市图像无效");return;}if(autoFetching){localReply(503,"天气正在更新，请稍后保存");return;}if(latitude!=autoLatitude||longitude!=autoLongitude)autoCache.ok=false;autoLatitude=latitude;autoLongitude=longitude;memcpy(autoCity,bitmap,320);autoNextFetch=0;}autoEnabled=enabled;autoMinute=-1;if(!autoSave()){autoEnabled=priorEnabled;autoLatitude=priorLat;autoLongitude=priorLon;memcpy(autoCity,priorCity,320);autoCache=priorCache;localReply(503,"设置保存失败，原配置保留");return;}localReply(200,"自主更新设置已保存");});
}
void updateAutonomy(){
 bool ready;AutoWeather result;portENTER_CRITICAL(&autoMux);ready=autoResultReady;if(ready){result=autoResult;autoResultReady=false;}portEXIT_CRITICAL(&autoMux);
 if(ready){autoFetching=false;autoLastHTTP=result.httpStatus;autoLastTLS=result.tlsError;autoLastAddress=result.address;if(result.ok){autoCache=result;autoError="";autoSave();autoMinute=-1;autoNextFetch=millis()+600000;}else{autoError="天气更新失败，保留缓存";autoNextFetch=millis()+120000;}if(bleSuspended)localRestartBle=true;}
 if(!autoEnabled||!localMode||!hasBase||localIncoming||provisionAttempt||autoFetching)return;
 if(NimBLEDevice::getInitialized()&&NimBLEDevice::getServer()&&NimBLEDevice::getServer()->getConnectedCount()>0)return;
 time_t now=time(nullptr);if(now>=1577836800LL&&autoMinute!=now/60){localSuspendBle();localIncoming=(uint8_t*)malloc(PLANE_BYTES);if(localIncoming){memcpy(localIncoming,PartImage,PLANE_BYTES);overlayAutonomy(localIncoming,localLayoutID);localPaint(localIncoming,false,true,true,0);autoMinute=now/60;localRelease();}}
 if(!autoFetching&&WiFi.status()==WL_CONNECTED&&now>=1577836800LL&&(!autoNextFetch||(long)(millis()-autoNextFetch)>=0)){localSuspendBle();localRestartBle=false;AutoJob* job=new AutoJob{autoLatitude,autoLongitude};autoFetching=true;if(xTaskCreate(fetchAutoWeather,"mojian-weather",10000,job,1,nullptr)!=pdPASS){delete job;autoFetching=false;autoNextFetch=millis()+120000;localRestartBle=true;autoError="内存不足，稍后重试";}}
}
