#pragma once
// GxEPD2 1.6.9 _Update_Full register block for GDEY075Z08, header-only so it
// can be checked on the host. Opt-in: the vendor full-refresh path is unchanged
// unless MOJIAN_EXPERIMENT_GX_FULL is defined.
template<class Command,class Data>
inline void applyGxFullRefreshSettings(Command command,Data data){
 command(0x00);data(0x0f);          // PANEL SETTING, BWOTP
 command(0x50);data(0x13);data(0x07); // VCOM/data interval, white for black/red
 command(0xE0);data(0x00);          // CCSET: no TSFIX, internal temperature
 command(0x41);data(0x00);          // TSE: internal temperature sensor
}
