#include <iostream>
#include <vector>
#include <string>
#include "src/app_config.h"
#include "src/json_parser.h"

int main() {
  std::string js = "{\"timestamp\":\"2026-01-29T22:08:52.795\",\"battery\":{\"cells\":6,\"voltage\":22.2,\"nominal\":22.200000000000003},\"sensor\":{\"type\":\"sensorless\"},\"motor\":{\"type\":\"BLDC\",\"kv\":1000,\"poles\":4},\"control\":{\"mode\":\"Throttle\",\"currentLimit\":51,\"pwmFrequency\":16},\"safety\":{\"maxTemperature\":60,\"overcurrentLimit\":100}}";
  std::vector<uint8_t> v(js.begin(), js.end());
  AppConfig cfg;
  bool ok = jsonparser::parse_json_to_appconfig(v, cfg);
  std::cout << "parse ok: " << ok << "\n";
  std::cout << "version: " << (int)cfg.version << "\n";
  std::cout << "battery_cells: " << (int)cfg.battery_cells << "\n";
  std::cout << "battery_voltage: " << cfg.battery_voltage << "\n";
  std::cout << "battery_nominal: " << cfg.battery_nominal << "\n";
  std::cout << "sensor_type: " << (int)cfg.sensor_type << "\n";
  std::cout << "sensor_max_rpm: " << cfg.sensor_max_rpm << "\n";
  std::cout << "motor_kv: " << cfg.motor_kv << "\n";
  std::cout << "motor_poles: " << (int)cfg.motor_poles << "\n";
  std::cout << "control_mode: " << (int)cfg.control_mode << "\n";
  std::cout << "control_current_limit: " << cfg.control_current_limit << "\n";
  std::cout << "control_pwm_frequency: " << cfg.control_pwm_frequency << "\n";
  std::cout << "safety_max_tempreature: " << (int)cfg.safety_max_tempreature << "\n";
  std::cout << "safety_overcurrent_limit: " << cfg.safety_overcurrent_limit << "\n";
  return 0;
}
