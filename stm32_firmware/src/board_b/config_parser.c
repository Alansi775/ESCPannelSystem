#include "config_parser.h"
#include <string.h>

// Simple binary parser: expects a layout in big-endian. The exact
// field offsets may be adjusted later to match the producer format.
// Current layout (offsets are relative to data[0]):
// 0-1: header (ignored)
// 2: type (ignored)
// 3-4: battery_voltage_mv (uint16_t, mV)
// 5-6: battery_nominal_mv (uint16_t, mV)
// 7: battery_cells (uint8_t)
// 8-9: sensor_max_rpm (uint16_t)
// 10-11: motor_kv (uint16_t)
// 12: motor_poles (uint8_t)
// 13: control_mode (uint8_t)
// 14-17: current_limit (uint32_t, mA)
// 18-19: pwm_frequency_khz (uint16_t)
// 20: brake_enabled (uint8_t)
// 21-22: max_temp (uint16_t)
// 23-26: overcurrent_limit (uint32_t, mA)

static uint16_t be16(const uint8_t* p) { return (uint16_t)(p[0] << 8 | p[1]); }
static uint32_t be32(const uint8_t* p) { return (uint32_t)(p[0] << 24 | p[1] << 16 | p[2] << 8 | p[3]); }

int parse_esc_config(const uint8_t* data, size_t len, esc_config_t* out_cfg) {
  if (!data || !out_cfg) return 0;
  if (len < 27) return 0; // not enough data for expected layout

  // Note: fields are read in big-endian per requirement
  out_cfg->battery_voltage_mv = (uint32_t)be16(&data[3]);
  out_cfg->battery_nominal_mv = (uint32_t)be16(&data[5]);
  out_cfg->battery_cells = (uint16_t)data[7];
  out_cfg->sensor_max_rpm = (uint32_t)be16(&data[8]);
  out_cfg->motor_kv = be16(&data[10]);
  out_cfg->motor_poles = data[12];
  out_cfg->control_mode = data[13];
  out_cfg->current_limit = be32(&data[14]);
  out_cfg->pwm_frequency_khz = be16(&data[18]);
  out_cfg->brake_enabled = data[20];
  out_cfg->max_temp = be16(&data[21]);
  out_cfg->overcurrent_limit = be32(&data[23]);

  // basic validation
  if (out_cfg->battery_cells == 0) return 0;
  if (out_cfg->pwm_frequency_khz == 0) out_cfg->pwm_frequency_khz = 20; // fallback

  return 1;
}
