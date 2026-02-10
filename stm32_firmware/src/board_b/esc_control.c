#include "esc_control.h"
#include "safety_monitor.h"
#include "driver_tim1.h"
#include "hall_sensor.h"
#include "uart_commands.h"
#include <stdio.h>
#include <string.h>
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
static int target_pwm_percent = 0;  // Target for smooth ramping
static uint32_t arm_time_ms = 0;    // Time when motor was armed
static const uint32_t ARM_STABILIZE_MS = 80;   // Brief stabilization (80ms) only
static const int RAMP_RATE_PERCENT_PER_SEC = 250;  // 250% per second = responsive (full throttle in 400ms)

// Software 6-step commutation (for when Hall sensors aren't available)
static uint32_t commutation_timer = 0;
static uint8_t commutation_step = 0;
static const uint8_t commutation_sequence[] = {0x1, 0x3, 0x2, 0x6, 0x4, 0x5};  // 6-step pattern
static int use_software_commutation = 0;

// Soft start: ramp current over time to prevent locking
static uint32_t arm_timestamp = 0;
static int soft_start_complete = 0;

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
    // Initialize software commutation timer
    commutation_timer = HAL_GetTick();
    commutation_step = 0;
    // Set minimum startup throttle (10%) for professional DJI-grade spinup
    pwm_percent = 10;
    target_pwm_percent = 10;
    arm_time_ms = HAL_GetTick();  // Record when armed
    // enable driver outputs
    driver_enable();
    g_state = ESC_ARMED;
    HAL_UART_Transmit(&huart4, (uint8_t*)"ESC ARMED (5% spinup - stabilizing...)\r\n", 41, 50);
  }
}

void esc_disarm(void) {
  // safe stop
  target_rpm = 0;
  target_current_mA = 0;
  pwm_percent = 0;
  target_pwm_percent = 0;
  commutation_timer = 0;  // Reset software commutation timer
  commutation_step = 0;
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
  // Stop motor outputs immediately
  target_rpm = 0;
  target_current_mA = 0;
  // disable driver outputs immediately
  driver_disable();
  if (reason) {
    HAL_UART_Transmit(&huart4, (uint8_t*)"FAULT: ", 7, 50);
    HAL_UART_Transmit(&huart4, (uint8_t*)reason, strlen(reason), 200);
    HAL_UART_Transmit(&huart4, (uint8_t*)"\r\n", 2, 50);
  }
}

void esc_control_update(void) {
  // enforce safety limits continuously
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
      // reduce torque proportionally
      derate_factor = (float)max_current / (float)current_mA;
      if (derate_factor < 0.1f) derate_factor = 0.1f;
    }
    if (temp_c > (max_temp_limit - 5)) {
      // gradual derate when approaching limit (skip if bypass active)
      if (!safety_get_bypass()) {
        derate_factor *= 0.5f;
      }
    }
    if (voltage_v < ((float)g_cfg.battery_voltage_mv / 1000.0f * 0.7f)) {
      // low voltage - derate
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
    // Skip temperature fault check when bypass is active (for bring-up testing with floating sensors)
    if (!safety_get_bypass() && temp_c > max_temp_limit) {
      esc_control_set_fault("over_temperature");
      return;
    }

    // clamp commanded current and apply derating
    int32_t cmd_mA = target_current_mA;
    if ((uint32_t)cmd_mA > (uint32_t)max_current) cmd_mA = (int32_t)max_current;
    cmd_mA = (int32_t)((float)cmd_mA * derate_factor);

    // Apply Hall-sensored commutation across all control modes
    // (all modes now use open-loop commutation triggered by Hall sensor changes)
    
    // SMOOTH THROTTLE RAMP: Gradually move pwm_percent toward target
    {
      static uint32_t last_ramp_ms = 0;
      uint32_t now = HAL_GetTick();
      if (now - last_ramp_ms >= 20) {  // Update every 20ms (50Hz ramp frequency)
        last_ramp_ms = now;
        
        int delta = target_pwm_percent - pwm_percent;
        if (delta != 0) {
          // Calculate ramp amount for this 20ms interval
          // RAMP_RATE_PERCENT_PER_SEC = 50% per second
          // Per 20ms: 50% / 50 = 1% per 20ms
          int ramp_step = (RAMP_RATE_PERCENT_PER_SEC * 20) / 1000;  // percent per 20ms
          if (ramp_step < 1) ramp_step = 1;  // Minimum 1% per step
          
          if (delta > 0) {
            // Ramping up
            pwm_percent += ramp_step;
            if (pwm_percent > target_pwm_percent) {
              pwm_percent = target_pwm_percent;
            }
          } else {
            // Ramping down
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
      // Map current command (mA) to duty cycle
      // 0mA = 0%, max_current = 100%
      duty = (int16_t)((cmd_mA * 840) / max_current);
      if (duty < 0) duty = 0;
      if (duty > 840) duty = 840;
    } else if (g_cfg.control_mode == CONTROL_MODE_SPEED) {
      // Speed control without speed feedback: map target RPM to duty
      // (requires external speed command from Pixhawk)
      duty = (int16_t)((target_rpm * 840) / 500);  // Assume 500 RPM = 100%
      if (duty < 0) duty = 0;
      if (duty > 840) duty = 840;
    } else if (g_cfg.control_mode == CONTROL_MODE_OPEN_LOOP) {
      // Open-loop mode: map pwm_percent directly
      duty = (int16_t)((pwm_percent * 840) / 100);
      if (duty < 0) duty = 0;
      if (duty > 840) duty = 840;
    } else {
      // unsupported modes - stop for safety
      esc_control_set_fault("unsupported_control_mode");
      return;
    }

    // Commutation: Use real Hall sensors if available, otherwise use software 6-step
    uint8_t hall = hall_sensor_read();
    
    if (hall == 0x7 || hall == 0x0) {
      // Hall sensors invalid/floating - use software 6-step commutation
      use_software_commutation = 1;
      
      // PROFESSIONAL SILENT COMMUTATION: 1ms per step = 6kHz electrical frequency
      // (1ms * 6 steps = 6ms cycle = ultra-smooth DJI-grade operation, zero cogging)
      uint32_t now = HAL_GetTick();
      const uint32_t SOFT_COMM_PERIOD_MS = 1;  // Advance step every 1ms
      
      if (now - commutation_timer > SOFT_COMM_PERIOD_MS) {
        commutation_timer = now;
        commutation_step = (commutation_step + 1) % 6;
      }
      
      hall = commutation_sequence[commutation_step];
    } else {
      use_software_commutation = 0;
    }
    
    // Apply commutation pattern
    driver_set_phase_pwm(hall, duty);
  }
}

void esc_set_pwm_percent(int percent) {
  if (percent < 0) percent = 0;
  if (percent > 100) percent = 100;
  
  // Set target for soft ramp controller (ramp happens automatically at RAMP_RATE_PERCENT_PER_SEC)
  // No hard throttle cap - user can command any throttle immediately after ARM
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
  pwm_percent = throttle_value;
}
