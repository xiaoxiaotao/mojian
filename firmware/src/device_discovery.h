#pragma once
#include <ESPmDNS.h>
// Stable board identity; not a secret or an authentication credential.
String deviceIdentity(){char id[24];snprintf(id,sizeof(id),"mojian-%012llx",(unsigned long long)(ESP.getEfuseMac()&0xffffffffffffULL));return String(id);}
void updateDeviceDiscovery(){
 static bool started=false;static unsigned long lastAttempt=0;static uint32_t activeGeneration=0;
 uint32_t generation=networkGeneration.load();if(started&&generation!=activeGeneration){MDNS.end();started=false;lastAttempt=0;}
 if(WiFi.status()!=WL_CONNECTED){if(started){MDNS.end();started=false;}return;}
 if(started || (lastAttempt && millis()-lastAttempt<10000))return;lastAttempt=millis();
 String name=deviceIdentity();if(!MDNS.begin(name.c_str()))return;
 MDNS.setInstanceName(name.c_str());MDNS.addService("mojian","tcp",80);MDNS.addServiceTxt("mojian","tcp","id",name);MDNS.addServiceTxt("mojian","tcp","api","1");started=true;activeGeneration=generation;Serial.printf("Discovery ready: %s.local\n",name.c_str());
}
