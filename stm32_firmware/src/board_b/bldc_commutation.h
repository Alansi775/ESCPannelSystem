#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize BLDC commutation engine
void bldc_commutation_init(void);

// Start open-loop commutation at specified frequency (Hz)
void bldc_commutation_start(float freq_hz);

// Stop commutation
void bldc_commutation_stop(void);

// Set commutation frequency (Hz) - controls speed
void bldc_commutation_set_frequency(float freq_hz);

// Set PWM duty cycle (0-100%) - controls torque
void bldc_commutation_set_duty(int percent);

// Call periodically from main loop to advance commutation state
void bldc_commutation_update(void);

// Check if commutation is active
int bldc_commutation_is_running(void);

#ifdef __cplusplus
}
#endif
