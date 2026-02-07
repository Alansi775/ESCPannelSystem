#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize UART command parser
void uart_commands_init(void);

// Feed bytes (non-blocking). Returns 1 if a full command processed.
int uart_commands_feed(uint8_t b);

// Return time (HAL_GetTick) of last received command (ms)
uint32_t uart_commands_last_seen_ms(void);

// Reset watchdog timer (called by PWM command in bypass mode)
void uart_commands_reset_watchdog(void);

#ifdef __cplusplus
}
#endif
