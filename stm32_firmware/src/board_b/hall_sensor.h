#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize Hall sensor inputs on PC0, PC1, PC2
void hall_sensor_init(void);

// Read current Hall sensor state (0-7, representing the 3 bits)
// Bit 0 = PC0 (HALL_U)
// Bit 1 = PC1 (HALL_V)
// Bit 2 = PC2 (HALL_W)
uint8_t hall_sensor_read(void);

// Get human-readable Hall state name
const char* hall_sensor_state_name(uint8_t state);

// Register callback for Hall state change (optional)
typedef void (*hall_callback_t)(uint8_t new_state);
void hall_sensor_set_callback(hall_callback_t cb);

#ifdef __cplusplus
}
#endif
