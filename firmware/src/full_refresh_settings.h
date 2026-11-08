#pragma once
// GxEPD2 1.6.9 full-refresh temperature block for GDEY075Z08.
// Header-only so it can be checked on the host. Opt-in: the vendor full-refresh
// path is unchanged unless MOJIAN_EXPERIMENT_GX_FULL_TEMP is defined.
//
// Deliberately does not write 0x50=0x13: UC8179 CDI DDX[1] is the red data
// polarity, so changing 0x11->0x13 requires inverting the red mask too. That is
// a separate experiment, not part of this single-factor temperature test.
template<class Command,class Data>
inline void applyGxFullTemperatureSettings(Command command,Data data){
 command(0xE0);data(0x00); // CCSET: no TSFIX, internal temperature sensor
 command(0x41);data(0x00); // TSE: internal temperature sensor
}
