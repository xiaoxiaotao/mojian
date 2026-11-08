#pragma once
#if defined(MOJIAN_EXPERIMENT_GX_FULL_TEMP) && defined(MOJIAN_EXPERIMENT_GX_FULL_CDI)
#error "Run full-refresh experiments separately"
#endif

// GxEPD2 1.6.9 full-refresh temperature block for GDEY075Z08.
// Header-only so it can be checked on the host. Opt-in: the vendor full-refresh
// path is unchanged unless a full-refresh experiment is defined.
//
// 0xE0/0x41: GxEPD2 enables the internal temperature sensor before refresh;
// the vendor full path does not. This is the clean single-factor candidate.
template<class Command,class Data>
inline void applyGxFullTemperatureSettings(Command command,Data data){
 command(0xE0);data(0x00); // CCSET: no TSFIX, internal temperature sensor
 command(0x41);data(0x00); // TSE: internal temperature sensor
}

// 0x50 CDI: DDX[1] is red data polarity. 0x11 (DDX=01) -> 0x13 (DDX=11)
// flips the red plane, so the static red mask must be inverted in the band.
template<class Command,class Data>
inline void applyGxFullCdiSettings(Command command,Data data){
 command(0x50);data(0x13);data(0x07);
}
inline unsigned char gxFullCdiRedWire(unsigned i,unsigned char value){
 return i>=8000&&i<10400?(unsigned char)~value:value;
}
