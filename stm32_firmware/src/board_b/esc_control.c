#include "esc_control.h"
#include "safety_monitor.h"
#include "driver_tim1.h"
#include "hall_sensor.h"
#include "uart_commands.h"
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "stm32f4xx_hal.h"

// UART handle is declared in main.cpp
extern UART_HandleTypeDef huart4;
extern int safety_get_bypass(void);
extern uint8_t hall_sensor_read(void);

static esc_config_t g_cfg;
static esc_state_t g_state = ESC_BOOT;
static float max_motor_voltage = 0.0f;
static uint32_t max_current = 0;
static uint32_t overcurrent_trip = 0;
static uint16_t max_temp_limit = 0;

// Targets
static int32_t target_rpm = 0;
static int32_t target_current_mA = 0;
static int pwm_percent = 0;
static int target_pwm_percent = 0;
static uint32_t arm_time_ms = 0;
static const uint32_t ARM_STABILIZE_MS = 80;
static const int RAMP_RATE_PERCENT_PER_SEC = 250;

// Simple 6-step commutation for Hall fallback
static uint8_t commutation_step = 0;
static const uint8_t commutation_sequence[] = {0x1, 0x3, 0x2, 0x6, 0x4, 0x5};
static uint32_t step_divider = 0;      // Counter for adaptive stepping
static uint32_t step_divider_low = 0;  // Counter for very low speeds

void esc_control_init(const esc_config_t* cfg) {
  if (cfg) memcpy(&g_cfg, cfg, sizeof(g_cfg));

  // Override control mode to OPEN_LOOP when safety bypass is active (for bring-up testing)
  if (safety_get_bypass()) {
    g_cfg.control_mode = CONTROL_MODE_OPEN_LOOP;
    HAL_UART_Transmit(&huart4, (uint8_t*)"CONTROL MODE OVERRIDDEN: OPEN_LOOP (BYPASS)\r\n", 45, 50);
    HAL_UART_Transmit(&huart4, (uint8_t*)"Temperature protection disabled (BYPASS)\r\n", 42, 50);
  }

  // Derive safety limits
  max_motor_voltage = (float)g_cfg.battery_nominal_mv / 1000.0f * 0.9f;
  max_current = g_cfg.current_limit;
  overcurrent_trip = g_cfg.overcurrent_limit;
  max_temp_limit = g_cfg.max_temp;

  // Initialize driver (keep outputs disabled until arm)
  driver_init();
  driver_disable();

  g_state = ESC_CONFIG_READY;
}

void esc_arm(void) {
  // Allow arming from CONFIG_READY (first arm) or WAIT_CONFIG (re-arm after disarm)
  if (g_state == ESC_CONFIG_READY || g_state == ESC_WAIT_CONFIG) {
    // do not allow arming during calibration
    if (safety_is_calibrating()) {
      HAL_UART_Transmit(&huart4, (uint8_t*)"ARM REJECTED: calibration active\r\n", 33, 50);
      return;
    }
    if (target_rpm != 0 || target_current_mA != 0) {
      HAL_UART_Transmit(&huart4, (uint8_t*)"ARM REJECTED: non-zero target\r\n", 30, 50);
      return;
    }
    
    // Initialize software commutation
    commutation_step = 0;
    step_divider = 0;
    step_divider_low = 0;
    
    // Set minimum startup throttle (10%)
    pwm_percent = 10;
    target_pwm_percent = 10;
    arm_time_ms = HAL_GetTick();
    
    // enable driver outputs
    driver_enable();
    g_state = ESC_ARMED;
    HAL_UART_Transmit(&huart4, (uint8_t*)"ESC ARMED\r\n", 11, 50);
  }
}

void esc_disarm(void) {
  // safe stop
  target_rpm = 0;
  target_current_mA = 0;
  pwm_percent = 0;
  target_pwm_percent = 0;
  commutation_step = 0;
  step_divider = 0;
  step_divider_low = 0;
  arm_time_ms = 0;
  
  // disable outputs
  driver_disable();
  g_state = ESC_WAIT_CONFIG;
  HAL_UART_Transmit(&huart4, (uint8_t*)"ESC DISARMED\r\n", 14, 50);
}


void esc_set_speed_rpm(int32_t rpm) {
  if (g_state == ESC_ARMED || g_state == ESC_RUNNING) {
    target_rpm = rpm;
    if (g_state == ESC_ARMED) g_state = ESC_RUNNING;
  }
}

void esc_set_torque_mA(int32_t milliamp) {
  if (g_state == ESC_ARMED || g_state == ESC_RUNNING) {
    target_current_mA = milliamp;
    if (g_state == ESC_ARMED) g_state = ESC_RUNNING;
  }
}

esc_state_t esc_control_get_state(void) { return g_state; }

void esc_control_set_fault(const char* reason) {
  g_state = ESC_FAULT;
  target_rpm = 0;
  target_current_mA = 0;
  driver_disable();
  if (reason) {
    HAL_UART_Transmit(&huart4, (uint8_t*)"FAULT: ", 7, 50);
    HAL_UART_Transmit(&huart4, (uint8_t*)reason, strlen(reason), 200);
    HAL_UART_Transmit(&huart4, (uint8_t*)"\r\n", 2, 50);
  }
}

void esc_control_update(void) {
  // === NORMAL MOTOR CONTROL ===
  if (g_state == ESC_ARMED || g_state == ESC_RUNNING) {
    // read sensors
    int32_t current_mA = safety_get_motor_current_mA();
    float voltage_v = safety_get_driver_voltage_v();
    uint16_t temp_c = safety_get_temperature_c();

    // watchdog: require recent UART commands (fail safe) - skip when bypass is active
    if (!safety_get_bypass()) {
      uint32_t last_cmd = uart_commands_last_seen_ms();
      if (HAL_GetTick() - last_cmd > 5000) {
        esc_control_set_fault("cmd_watchdog");
        return;
      }
    }

    // derating and protective actions
    float derate_factor = 1.0f;
    if ((uint32_t)current_mA > max_current) {
      derate_factor = (float)max_current / (float)current_mA;
      if (derate_factor < 0.1f) derate_factor = 0.1f;
    }
    if (temp_c > (max_temp_limit - 5)) {
      if (!safety_get_bypass()) {
        derate_factor *= 0.5f;
      }
    }
    if (voltage_v < ((float)g_cfg.battery_voltage_mv / 1000.0f * 0.7f)) {
      derate_factor *= 0.5f;
    }

    if ((uint32_t)current_mA > overcurrent_trip) {
      esc_control_set_fault("overcurrent_trip");
      return;
    }
    if (voltage_v > max_motor_voltage + 0.5f) {
      esc_control_set_fault("over_voltage");
      return;
    }
    if (!safety_get_bypass() && temp_c > max_temp_limit) {
      esc_control_set_fault("over_temperature");
      return;
    }

    // clamp commanded current and apply derating
    int32_t cmd_mA = target_current_mA;
    if ((uint32_t)cmd_mA > (uint32_t)max_current) cmd_mA = (int32_t)max_current;
    cmd_mA = (int32_t)((float)cmd_mA * derate_factor);

    // SMOOTH THROTTLE RAMP
    {
      static uint32_t last_ramp_ms = 0;
      uint32_t now = HAL_GetTick();
      if (now - last_ramp_ms >= 20) {
        last_ramp_ms = now;
        
        int delta = target_pwm_percent - pwm_percent;
        if (delta != 0) {
          int ramp_step = (RAMP_RATE_PERCENT_PER_SEC * 20) / 1000;
          if (ramp_step < 1) ramp_step = 1;
          
          if (delta > 0) {
            pwm_percent += ramp_step;
            if (pwm_percent > target_pwm_percent) {
              pwm_percent = target_pwm_percent;
            }
          } else {
            pwm_percent -= ramp_step;
            if (pwm_percent < target_pwm_percent) {
              pwm_percent = target_pwm_percent;
            }
          }
        }
      }
    }
    
    int16_t duty = 0;
    
    if (g_cfg.control_mode == CONTROL_MODE_TORQUE) {
      duty = (int16_t)((cmd_mA * 1680) / max_current);
      if (duty < 0) duty = 0;
      if (duty > 1680) duty = 1680;
    } else if (g_cfg.control_mode == CONTROL_MODE_SPEED) {
      duty = (int16_t)((target_rpm * 1680) / 500);
      if (duty < 0) duty = 0;
      if (duty > 1680) duty = 1680;
    } else if (g_cfg.control_mode == CONTROL_MODE_OPEN_LOOP) {
      duty = (int16_t)((pwm_percent * 1680) / 100);
      if (duty < 0) duty = 0;
      if (duty > 1680) duty = 1680;
    } else {
      esc_control_set_fault("unsupported_control_mode");
      return;
    }

    // Commutation: Use real Hall sensors if available, otherwise use software 6-step
    uint8_t hall = hall_sensor_read();
    
    if (hall == 0x7 || hall == 0x0) {
      // Hall sensors invalid/floating - use software 6-step with adaptive stepping
      if (duty > 500) {
        // High power: step at every 1ms (fastest)
        step_divider++;
        if (step_divider >= 1) {
          step_divider = 0;
          commutation_step = (commutation_step + 1) % 6;
        }
      } else if (duty > 200) {
        // Medium power: step every 2ms
        step_divider++;
        if (step_divider >= 2) {
          step_divider = 0;
          commutation_step = (commutation_step + 1) % 6;
        }
      } else if (duty > 0) {
        // Low power: step every 3ms (more torque)
        step_divider_low++;
        if (step_divider_low >= 3) {
          step_divider_low = 0;
          commutation_step = (commutation_step + 1) % 6;
        }
      }
      
      hall = commutation_sequence[commutation_step];
    }
    
    // Apply commutation
    driver_set_phase_pwm(hall, duty);
  }
}

void esc_set_pwm_percent(int percent) {
  if (percent < 0) percent = 0;
  if (percent > 100) percent = 100;
  target_pwm_percent = percent;
}

void esc_set_throttle(int throttle_value) {
  // throttle_value: 0-1000 (Pixhawk standard) or 0-100
  // Auto-detect and convert to 0-100%
  if (throttle_value > 100) {
    // Likely 0-1000 format
    throttle_value = (throttle_value * 100) / 1000;
  }
  if (throttle_value < 0) throttle_value = 0;
  if (throttle_value > 100) throttle_value = 100;
  
  esc_set_pwm_percent(throttle_value);
}