#include "EPD_SPI.h"
#include <SPI.h>
#include "EPD.h"

//SPI write byte
void SPI_Write(unsigned char value)
{
   SPI.transfer(value);
}

//SPI write command
void EPD_W21_WriteCMD(unsigned char command)
{
    if(displayGuard.failed)return;
	EPD_W21_CS_0;
	EPD_W21_DC_0;  // D/C#   0:command  1:data
	SPI_Write(command);
	EPD_W21_CS_1;
}
//SPI write data
void EPD_W21_WriteDATA(unsigned char datas)
{
    if(displayGuard.failed)return;
	EPD_W21_CS_0;
	EPD_W21_DC_1;  // D/C#   0:command  1:data
	SPI_Write(datas);
	EPD_W21_CS_1;
}

bool EPD_FaultPowerOff(void)
{
    if(!displayGuard.failed)return false;
    if(displayGuard.shutdownAttempted)return displayGuard.shutdownConfirmed;
    displayGuard.shutdownAttempted=true;
    // UC8179 / GxEPD2 shutdown order: POWER_OFF, BUSY ready, DEEP_SLEEP A5.
    // Only these fixed bytes bypass the fault latch. A broken BUSY line or
    // unresponsive controller means physical power-off cannot be confirmed.
    EPD_W21_CS_0;EPD_W21_DC_0;SPI_Write(0x02);EPD_W21_CS_1;
    delay(1); // Let BUSY assert before examining it.
    uint32_t began=millis();
    while(isEPD_W21_BUSY==0){
        if(uint32_t(millis()-began)>=1000U)return false;
        delay(1);
    }
    EPD_W21_CS_0;EPD_W21_DC_0;SPI_Write(0x07);EPD_W21_CS_1;
    EPD_W21_CS_0;EPD_W21_DC_1;SPI_Write(0xA5);EPD_W21_CS_1;
    displayGuard.shutdownConfirmed=true;
    return true;
}


// Define SPI pins
#define SPI_MISO 19
#define SPI_MOSI 23
#define SPI_SCK  18
#define SPI_CS   27
// Save original SPI settings
SPIClass* originalSPI = &SPI;
uint8_t originalSdaPin = SPI_MISO;
uint8_t originalSclPin = SPI_SCK;
bool spiInitialized = false;
unsigned char EPD_W21_ReadDATA(void)
{
    unsigned char i, j = 0;
    // Save current hardware SPI configuration (only on first call)
    if (!spiInitialized) {
        spiInitialized = true;
    }
    originalSPI->end();    // Disable hardware SPI
    // Configure software SPI pins
    pinMode(SPI_MOSI, INPUT);     // SDA IN
    pinMode(SPI_SCK, OUTPUT);    // SCL OUT
    EPD_W21_CS_0;
    EPD_W21_DC_1;           // Data mode
    // Software SPI read
    for (i = 0; i < 8; i++) {
        digitalWrite(SPI_SCK, HIGH);  // SCL HIGH
        delayMicroseconds(2);    // More precise timing
        j = (j << 1);
        if (digitalRead(23) == HIGH)
            j |= 0x01;
        delayMicroseconds(2);
        digitalWrite(SPI_SCK, LOW);   // SCL LOW
    }
    EPD_W21_CS_1;
    pinMode(SPI_MOSI, OUTPUT);// Restore MOSI to output mode
    // Re-enable hardware SPI
    // Reinitialize with predefined default pins
    originalSPI->begin(originalSclPin, originalSdaPin, SPI_MOSI, SPI_CS);
    return j;
}
