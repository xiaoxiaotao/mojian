#pragma once
#include <atomic>
std::atomic<uint32_t> networkGeneration{0},networkDisconnects{0};
std::atomic<unsigned> networkLastReason{0};
uint32_t networkReconnects=0,networkRadioRestarts=0;
