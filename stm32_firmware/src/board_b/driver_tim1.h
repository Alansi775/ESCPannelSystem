#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize PWM hardware on TIM1 (PA8, PA9, PA10 for U/V/W phases)
void driver_init_tim1(void);

// Wrapper for compatibility with old code
void driver_init(void);

// Enable/disable motor driver outputs
void driver_enable(void);
void driver_disable(void);

// Set phase PWM for Hall-sensored commutation
// Input: phase duty (0-1000) with optional direction
void driver_set_phase_pwm(uint8_t hall_state, int16_t duty);

// Direct PWM setting for testing (0-840 scale)
void driver_set_pwm_u(int16_t duty);
void driver_set_pwm_v(int16_t duty);
void driver_set_pwm_w(int16_t duty);

// Query driver state
int driver_is_enabled(void);

#ifdef __cplusplus
}
#endif
