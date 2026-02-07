#pragma once

#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize safety monitor hardware (ADC, temp sensor, etc.)
void safety_monitor_init(void);

// Runtime getters (implementations may read ADC / sensors)
int32_t safety_get_motor_current_mA(void);
float   safety_get_driver_voltage_v(void);
uint16_t safety_get_temperature_c(void);

// Force a single ADC sample for all channels (non-blocking not required)
void safety_sample_once(void);

// Calibration mode: when enabled, safety monitor will print raw ADC and converted values periodically.
void safety_enable_calibration(int enable);
int safety_is_calibrating(void);

// Raw ADC getters (last sampled values)
uint32_t safety_get_last_raw_vbus(void);
uint32_t safety_get_last_raw_shunt(void);
uint32_t safety_get_last_raw_temp(void);

// SAFE status: returns 1 if SAFE, 0 if not
int safety_get_safe_flag(void);

// Sensor bypass control for bring-up testing
void safety_set_bypass(int enable);
int safety_get_bypass(void);

#ifdef __cplusplus
}
#endif
