#ifndef APP_CONFIG_H
#define APP_CONFIG_H
#include <stdint.h>

enum SensorType : uint8_t { SENSOR_UNKNOWN = 0, SENSORLESS = 1 };
enum ControlMode : uint8_t { MODE_UNKNOWN = 0, MODE_THROTTLE = 1 };

struct AppConfig {
  uint8_t version = 1;
  uint8_t battery_cells = 0;
  float battery_voltage = 0.0f;
  float battery_nominal = 0.0f;
  uint8_t sensor_type = 0;
  uint32_t sensor_max_rpm = 0;
  int32_t motor_kv = 0;
  uint8_t motor_poles = 0;
  uint8_t control_mode = 0;
  uint16_t control_current_limit = 0;
  uint16_t control_pwm_frequency = 0;
  uint8_t control_brake_enabled = 0;
  uint8_t safety_max_tempreature = 0;
  uint16_t safety_overcurrent_limit = 0;
  uint8_t reserved[3] = {0,0,0};
};

#endif // APP_CONFIG_H
