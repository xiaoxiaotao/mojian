#pragma once
#include "network_recovery_policy.h"
NetworkRecoveryPolicy networkRecovery;
void updateNetworkRecovery(){
 bool online=WiFi.status()==WL_CONNECTED && (uint32_t)WiFi.localIP()!=0;
 // Never race credential provisioning, an upload or the weather TLS worker.
 unsigned action=networkRecovery.next(millis(),online,provisionAttempt.load()||autoFetching||localIncoming!=nullptr);
 if(action){
  String ssid,password;savedNetwork(ssid,password);
  if(ssid.length()){
   ++networkReconnects;
   if(action==2){++networkRadioRestarts;WiFi.mode(WIFI_OFF);WiFi.mode(WIFI_STA);WiFi.setAutoReconnect(true);WiFi.begin(ssid.c_str(),password.c_str());}
   else if(!WiFi.reconnect())WiFi.begin(ssid.c_str(),password.c_str());
   Serial.printf("Network recovery: action=%u attempts=%u heap=%u largest=%u\n",action,networkRecovery.attempts,ESP.getFreeHeap(),ESP.getMaxAllocHeap());
  }
 }
 static uint32_t servingGeneration=0;
 uint32_t generation=networkGeneration.load();
 if(online && generation!=servingGeneration && !localIncoming && !autoFetching && !provisionAttempt){
  // Disconnected TCP clients can outlive an IP lease. Rebind without touching display state.
  deviceWeb.stop();deviceWeb.begin();servingGeneration=generation;
  Serial.printf("HTTP listener rebound; network generation=%u\n",generation);
 }
}
