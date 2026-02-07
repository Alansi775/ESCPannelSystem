#pragma once
#include "config_parser.h"

#ifdef __cplusplus
extern "C" {
#endif

// Initialize FOC motor structures with config
int motor_initFOC(const esc_config_t* cfg);

// Run control loop step (should be called frequently)
void motor_loopFOC(void);

// Apply target: torque in mA or speed in rpm depending on mode
void motor_move_torque_mA(int32_t milliamp);
void motor_move_speed_rpm(int32_t rpm);

#ifdef __cplusplus
}
#endif
