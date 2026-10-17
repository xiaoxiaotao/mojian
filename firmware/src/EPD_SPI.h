#ifndef _EPD_SPI_H_
#define _EPD_SPI_H_
#include "Arduino.h"

//IO settings
/*
ESP32-WROOM-32D (Using hardware SPI)
BUSY——13
RES——12
DC——14
CS——27
SCK—GPIO18
SDIN—GPIO23
*/
#define isEPD_W21_BUSY digitalRead(13)  //BUSY
#define EPD_W21_RST_0 digitalWrite(12,LOW)  //RES
#define EPD_W21_RST_1 digitalWrite(12,HIGH)
#define EPD_W21_DC_0  digitalWrite(14,LOW) //DC
#define EPD_W21_DC_1  digitalWrite(14,HIGH)
#define EPD_W21_CS_0 digitalWrite(27,LOW) //CS
#define EPD_W21_CS_1 digitalWrite(27,HIGH)


void SPI_Write(unsigned char value);
void EPD_W21_WriteDATA(unsigned char datas);
void EPD_W21_WriteCMD(unsigned char command);
unsigned char EPD_W21_ReadDATA(void);

#endif
