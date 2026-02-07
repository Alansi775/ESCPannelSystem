#pragma once

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Control mode constants
#define CONTROL_MODE_OPEN_LOOP    0
#define CONTROL_MODE_TORQUE       1
#define CONTROL_MODE_SPEED        2

typedef struct {
  uint16_t battery_cells;
  uint32_t battery_voltage_mv;
  uint32_t battery_nominal_mv;
  uint8_t sensor_type;
  uint32_t sensor_max_rpm;
  uint16_t motor_kv;
  uint8_t motor_poles;
  uint8_t control_mode;
  uint32_t current_limit;
  uint16_t pwm_frequency_khz;
  uint8_t brake_enabled;
  uint16_t max_temp;
  uint32_t overcurrent_limit;
} esc_config_t;

// Parse a binary stored frame into esc_config_t.
// Returns 1 on success, 0 on failure. Expects big-endian fields.
int parse_esc_config(const uint8_t* data, size_t len, esc_config_t* out_cfg);

#ifdef __cplusplus
}
#endif
