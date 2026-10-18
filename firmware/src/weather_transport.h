#pragma once
#include <WiFiUdp.h>
#include "weather_dns.h"
inline bool weatherPublicIP(const IPAddress& ip){uint8_t bytes[]={ip[0],ip[1],ip[2],ip[3]};return weatherPublicIP(bytes);}
// Per-weather-request fallback only. Never reconfigures the device's global DNS.
inline bool resolveWeather(IPAddress& result){static const uint8_t question[]={3,'a','p','i',10,'o','p','e','n','-','m','e','t','e','o',3,'c','o','m',0,0,1,0,1};
 for(IPAddress resolver:{IPAddress(223,5,5,5),IPAddress(119,29,29,29)}){WiFiUDP udp;if(!udp.begin(0))continue;uint16_t id=(uint16_t)esp_random();uint8_t packet[12+sizeof question]={};packet[0]=id>>8;packet[1]=id;packet[2]=1;packet[5]=1;memcpy(packet+12,question,sizeof question);udp.beginPacket(resolver,53);udp.write(packet,sizeof packet);udp.endPacket();unsigned long began=millis();while(millis()-began<3000){int n=udp.parsePacket();if(n>0){uint8_t response[512],ip[4];int received=udp.read(response,sizeof response);if(udp.remoteIP()==resolver&&udp.remotePort()==53&&received>0&&weatherParseDNS(response,received,id,ip)){result=IPAddress(ip);udp.stop();return true;}}vTaskDelay(pdMS_TO_TICKS(20));}udp.stop();}return false;}
class WeatherTLS:public WiFiClientSecure {
public:
 IPAddress resolved;
 using WiFiClientSecure::connect;
 int connect(const char* host,uint16_t port)override{return connect(host,port,15000);}
 int connect(const char* host,uint16_t port,int32_t timeout)override{if(strcmp(host,"api.open-meteo.com")||port!=443)return 0;setTimeout((timeout>0?timeout:15000)/1000);IPAddress system;if(WiFi.hostByName(host,system)&&weatherPublicIP(system)){resolved=system;if(WiFiClientSecure::connect(system,port,host,WEATHER_ROOTS,nullptr,nullptr))return 1;}IPAddress direct;if(!resolveWeather(direct))return 0;resolved=direct;return WiFiClientSecure::connect(direct,port,host,WEATHER_ROOTS,nullptr,nullptr);}
};
