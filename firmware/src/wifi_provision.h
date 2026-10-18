#pragma once
#include <Preferences.h>
#include <atomic>
#include "provision_frames.h"
Preferences wifiPrefs;
std::atomic<const char*> provisionStatus{"ready"};
ProvisionFrames provisionFrames;
String pendingSSID,pendingPassword,attemptSSID,attemptPassword;
SemaphoreHandle_t provisionMutex=nullptr;
bool provisionPending=false,bootHeld=false,bootTriggered=false;
std::atomic<bool> provisionAttempt{false};
unsigned long provisionUntil=0,provisionStarted=0,bootBegan=0;
bool provisionOpen(){return provisionUntil!=0&&(int32_t)(provisionUntil-millis())>0;}
void savedNetwork(String& ssid,String& pass){JsonDocument j;String value=wifiPrefs.getString("network","");if(value.length()&&!deserializeJson(j,value)){ssid=j["ssid"].as<String>();pass=j["password"].as<String>();}else{ssid=wifiPrefs.getString("ssid",WEATHER_WIFI_SSID);pass=wifiPrefs.getString("pass",WEATHER_WIFI_PASSWORD);}}
void beginSavedWifi(){wifiPrefs.begin("mojian-wifi",false);String ssid,pass;savedNetwork(ssid,pass);WiFi.mode(WIFI_STA);WiFi.setAutoReconnect(true);if(ssid.length())WiFi.begin(ssid.c_str(),pass.c_str());provisionUntil=(wifiPrefs.isKey("network")||wifiPrefs.isKey("ssid"))?0:millis()+300000;provisionMutex=xSemaphoreCreateMutex();pinMode(0,INPUT_PULLUP);}
class WifiProvisionCallbacks:public NimBLECharacteristicCallbacks {
 void onRead(NimBLECharacteristic* c)override{String result=provisionStatus.load();c->setValue((const uint8_t*)result.c_str(),result.length());}
 void onWrite(NimBLECharacteristic* c)override{
  if(!provisionOpen()){provisionFrames.reset();provisionStatus="press-boot";return;}auto bytes=c->getValue();auto result=provisionFrames.feed(bytes.data(),bytes.size());if(result==ProvisionFrames::INVALID){provisionStatus="invalid";return;}if(result==ProvisionFrames::MORE){provisionStatus="receiving";return;}
  JsonDocument j;bool valid=!deserializeJson(j,provisionFrames.data())&&j["ssid"].is<String>()&&j["password"].is<String>();provisionFrames.reset();
  if(!valid){provisionStatus="invalid";return;}String ssid=j["ssid"].as<String>(),password=j["password"].as<String>();
  if(!ssid.length()||ssid.length()>32||(password.length()!=0&&(password.length()<8||password.length()>63))){provisionStatus="invalid";return;}
  if(xSemaphoreTake(provisionMutex,pdMS_TO_TICKS(100))!=pdTRUE){provisionStatus="busy";return;}
  if(provisionAttempt||provisionPending){provisionStatus="busy";}else{pendingSSID=ssid;pendingPassword=password;provisionPending=true;provisionStatus="accepted";}xSemaphoreGive(provisionMutex);
 }
};
WifiProvisionCallbacks wifiProvisionCallbacks;
void updateProvisioning(){
 if(provisionUntil&&!provisionOpen())provisionUntil=0;
 bool held=digitalRead(0)==LOW;if(held&&!bootHeld){bootBegan=millis();bootTriggered=false;}if(held&&!bootTriggered&&millis()-bootBegan>=2000){provisionUntil=millis()+300000;provisionStatus="ready";bootTriggered=true;}bootHeld=held;
 if(provisionMutex&&xSemaphoreTake(provisionMutex,0)==pdTRUE){if(provisionPending){attemptSSID=pendingSSID;attemptPassword=pendingPassword;pendingSSID="";pendingPassword="";provisionPending=false;provisionAttempt=true;provisionStarted=millis();WiFi.disconnect(false,false);WiFi.begin(attemptSSID.c_str(),attemptPassword.c_str());}xSemaphoreGive(provisionMutex);}
 if(!provisionAttempt)return;
 if(millis()-provisionStarted>=1500&&WiFi.status()==WL_CONNECTED&&WiFi.SSID()==attemptSSID){JsonDocument saved;saved["ssid"]=attemptSSID;saved["password"]=attemptPassword;String value;serializeJson(saved,value);if(wifiPrefs.putString("network",value)!=value.length()){provisionAttempt=false;provisionStatus="storage-failed";String oldSSID,oldPass;savedNetwork(oldSSID,oldPass);if(oldSSID.length())WiFi.begin(oldSSID.c_str(),oldPass.c_str());attemptSSID="";attemptPassword="";return;}attemptSSID="";attemptPassword="";provisionAttempt=false;provisionStatus="connected";provisionUntil=0;}
 else if(millis()-provisionStarted>=30000){attemptSSID="";attemptPassword="";provisionAttempt=false;provisionStatus="failed";String ssid,pass;savedNetwork(ssid,pass);if(ssid.length())WiFi.begin(ssid.c_str(),pass.c_str());}
}
