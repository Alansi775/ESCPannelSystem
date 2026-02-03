#include "protocol.h"
#include <Arduino.h>
#include <math.h>
#include <cstring>
#include <cstdint>
#include <cstddef>

// Pack AppConfig into the locked V2 frame format (29 bytes total)
// Format (exact order):
// Header (2B) | Version (1B) | Cells (1B) | Voltage mV (2B) | Nominal mV (2B) |
// Sensor Type (2B) | Max RPM (2B) | KV (2B) | Poles (1B) | Control Mode (1B) |
// Current Limit (2B) | PWM Freq (2B) | Brake (1B) | Max Temp (2B) | Overcurrent (2B) |
// Reserved (3B) | Checksum (1B)
size_t pack_appconfig_frame(const AppConfig& cfg, uint8_t* buf, size_t bufsize) {
  const size_t FRAME_LEN = 29;
  if (!buf || bufsize < FRAME_LEN) return 0;
  size_t idx = 0;
  buf[idx++] = 0xAA;
  buf[idx++] = 0x55;
  // version
  buf[idx++] = cfg.version;
  // cells
  buf[idx++] = cfg.battery_cells;
  // voltage mV (uint16 BE)
  uint16_t bv = (uint16_t)roundf(cfg.battery_voltage * 1000.0f);
  buf[idx++] = (uint8_t)((bv >> 8) & 0xFF);
  buf[idx++] = (uint8_t)(bv & 0xFF);
  // nominal mV
  uint16_t bn = (uint16_t)roundf(cfg.battery_nominal * 1000.0f);
  buf[idx++] = (uint8_t)((bn >> 8) & 0xFF);
  buf[idx++] = (uint8_t)(bn & 0xFF);
  // sensor type (2B, BE)
  uint16_t st = (uint16_t)cfg.sensor_type;
  buf[idx++] = (uint8_t)((st >> 8) & 0xFF);
  buf[idx++] = (uint8_t)(st & 0xFF);
  // sensor max rpm (2B BE)
  uint16_t mr = (uint16_t)cfg.sensor_max_rpm;
  buf[idx++] = (uint8_t)((mr >> 8) & 0xFF);
  buf[idx++] = (uint8_t)(mr & 0xFF);
  // motor KV (2B BE)
  uint16_t kv = (uint16_t)cfg.motor_kv;
  buf[idx++] = (uint8_t)((kv >> 8) & 0xFF);
  buf[idx++] = (uint8_t)(kv & 0xFF);
  // poles (1B)
  buf[idx++] = cfg.motor_poles;
  // control mode (1B)
  buf[idx++] = cfg.control_mode;
  // current limit (2B BE)
  buf[idx++] = (uint8_t)((cfg.control_current_limit >> 8) & 0xFF);
  buf[idx++] = (uint8_t)(cfg.control_current_limit & 0xFF);
  // pwm frequency (2B BE)
  buf[idx++] = (uint8_t)((cfg.control_pwm_frequency >> 8) & 0xFF);
  buf[idx++] = (uint8_t)(cfg.control_pwm_frequency & 0xFF);
  // brake (1B)
  buf[idx++] = cfg.control_brake_enabled;
  // max temperature (2B BE)
  buf[idx++] = (uint8_t)((cfg.safety_max_tempreature >> 8) & 0xFF);
  buf[idx++] = (uint8_t)(cfg.safety_max_tempreature & 0xFF);
  // overcurrent (2B BE)
  buf[idx++] = (uint8_t)((cfg.safety_overcurrent_limit >> 8) & 0xFF);
  buf[idx++] = (uint8_t)(cfg.safety_overcurrent_limit & 0xFF);
  // reserved 3 bytes
  buf[idx++] = cfg.reserved[0];
  buf[idx++] = cfg.reserved[1];
  buf[idx++] = cfg.reserved[2];

  // checksum: XOR of bytes from version (index 2) up to last payload byte (index FRAME_LEN-2)
  uint8_t chk = 0;
  for (size_t i = 2; i < FRAME_LEN - 1; ++i) chk ^= buf[i];
  buf[idx++] = chk;

  // Debug prints
  if (Serial) {
    Serial.print("Frame bytes: ");
    Serial.println((int)FRAME_LEN);
    Serial.print("Computed CS: ");
    Serial.println(chk, HEX);
  }

  return idx;
}

static void _print_hex_to_serial(const uint8_t* buf, size_t len) {
  for (size_t i = 0; i < len; ++i) {
    uint8_t v = buf[i];
    char s[3];
    const char* hex = "0123456789ABCDEF";
    s[0] = hex[(v >> 4) & 0xF];
    s[1] = hex[v & 0xF];
    s[2] = '\0';
    Serial.print(s);
    if (i + 1 < len) Serial.print(' ');
  }
  Serial.println();
}

void build_and_print_frame_v2(const AppConfig& cfg) {
  uint8_t buf[64];
  size_t flen = pack_appconfig_frame(cfg, buf, sizeof(buf));
  if (flen == 0) {
    Serial.println("Failed to build V2 frame");
    return;
  }
  _print_hex_to_serial(buf, flen);
}

bool send_frame_can(const uint8_t* data, size_t len) {
  // CAN not implemented in this board build; return false stub
  (void)data; (void)len;
  return false;
}

bool send_frame_i2c(const uint8_t* data, size_t len, uint8_t addr) {
  // I2C not implemented; stub
  (void)data; (void)len; (void)addr;
  return false;
}
