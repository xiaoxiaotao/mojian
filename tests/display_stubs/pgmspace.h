#pragma once
#include <cstdint>
#define pgm_read_byte(address) (*reinterpret_cast<const uint8_t*>(address))
