#pragma once
#include "config_parser.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum { ESC_BOOT=0, ESC_WAIT_CONFIG, ESC_CONFIG_READY, ESC_ARMED, ESC_RUNNING, ESC_FAULT } esc_state_t;

// Initialize controller with parsed config
void esc_control_init(const esc_config_t* cfg);

// Arm / disarm
void esc_arm(void);
void esc_disarm(void);

// Set targets (called from command parser)
void esc_set_speed_rpm(int32_t rpm);
void esc_set_torque_mA(int32_t milliamp);

// Periodic update to apply control and enforce limits (call from loop)
void esc_control_update(void);

// Query current state
esc_state_t esc_control_get_state(void);

// Set PWM duty for open-loop testing (0-100%)
void esc_set_pwm_percent(int percent);

// Set throttle directly (0-1000 for Pixhawk compatibility, or 0-100%)
void esc_set_throttle(int throttle_value);

#ifdef __cplusplus
}
#endif
