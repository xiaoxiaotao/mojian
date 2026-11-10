#pragma once
#include <atomic>
#include <stdint.h>

// SPI worker/main-loop observations, not optical results or measured voltages.
struct DisplayTelemetry {
 std::atomic<uint32_t> refreshCommands{0},refreshCompleted{0},differentialWindows{0};
 std::atomic<uint32_t> autonomyWindows{0},commitWindows{0},clockWindows{0},fullRefreshes{0};
 std::atomic<uint32_t> partialWindowsSinceFull{0},partialAreaSinceFull{0};
 static constexpr uint32_t kFullAreaBudget=5U*800U*480U;
 std::atomic<uint32_t> lastRefreshWaitMs{0},powerOffWaits{0},lastPowerOffWaitMs{0};
 std::atomic<bool> lastPowerOffBusyReady{false},lastPowerOffBusySeen{false};
};
