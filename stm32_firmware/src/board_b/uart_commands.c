#include "uart_commands.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "esc_control.h"
#include "stm32f4xx_hal.h"
#include "safety_monitor.h"
#include "frame_store.h"
#include "hall_sensor.h"
#include "driver_tim1.h"

extern UART_HandleTypeDef huart4;

// Simple line-based command parser over UART4. Commands are ASCII lines
// terminated by \n. Recognized commands (case-insensitive):
// ARM, STOP, SPD <rpm>, TRQ <mA>

static char cmd_buf[64];
static size_t cmd_pos = 0;
static volatile uint32_t last_cmd_ms = 0;

void uart_commands_init(void) {
  cmd_pos = 0;
  memset(cmd_buf, 0, sizeof(cmd_buf));
  last_cmd_ms = HAL_GetTick();
}

static void process_command(const char* s) {
  if (!s) return;
  // trim
  while (*s == ' ' || *s == '\t') ++s;
  
  // === SHORT COMMAND ALIASES FOR DRONE CONTROL ===
  // a/A = ARM
  if ((s[0] == 'a' || s[0] == 'A') && s[1] == '\0') {
    esc_arm();
    return;
  }
  // s/S = STOP/DISARM
  if ((s[0] == 's' || s[0] == 'S') && s[1] == '\0') {
    esc_disarm();
    return;
  }
  // t N = THROTTLE N% (e.g., "t 50" or "t50")
  if (s[0] == 't' || s[0] == 'T') {
    const char* p = s + 1;
    while (*p == ' ') ++p;
    int percent = atoi(p);
    if (percent < 0) percent = 0;
    if (percent > 100) percent = 100;
    esc_set_pwm_percent(percent);
    // Minimal output for fast drone control feedback
    if (percent == 0) {
      HAL_UART_Transmit(&huart4, (uint8_t*)"OK\r\n", 4, 50);
    } else {
      char buf[8];
      snprintf(buf, sizeof(buf), "%d\r\n", percent);
      HAL_UART_Transmit(&huart4, (uint8_t*)buf, strlen(buf), 50);
    }
    return;
  }
  
  // === FULL COMMAND NAMES (BACKWARDS COMPATIBLE) ===
  if (strcasecmp(s, "ARM") == 0) {
    esc_arm();
    return;
  }
  if (strncasecmp(s, "CAL", 3) == 0) {
    const char* p = s + 3;
    while (*p == ' ') ++p;
    if (strcasecmp(p, "START") == 0) {
      safety_enable_calibration(1);
      HAL_UART_Transmit(&huart4, (uint8_t*)"CAL: STARTED\r\n", 15, 50);
      return;
    } else if (strcasecmp(p, "STOP") == 0) {
      safety_enable_calibration(0);
      HAL_UART_Transmit(&huart4, (uint8_t*)"CAL: STOPPED\r\n", 15, 50);
      return;
    }
  }
  if (strcasecmp(s, "HALL") == 0) {
    // Read Hall continuously for 500ms to see pattern
    uint8_t states[100];
    int count = 0;
    uint32_t start = HAL_GetTick();
    while (HAL_GetTick() - start < 500 && count < 100) {
      states[count++] = hall_sensor_read();
      delay(10);
    }
    
    char buf[200];
    int n = snprintf(buf, sizeof(buf), "HALL READ 500ms (%d samples):\r\n", count);
    HAL_UART_Transmit(&huart4, (uint8_t*)buf, n, 50);
    
    // Show last 10 readings and current state
    for (int i = (count-10 > 0) ? count-10 : 0; i < count; i++) {
      n = snprintf(buf, sizeof(buf), "  %d: 0x%X (%s)\r\n", i, states[i], hall_sensor_state_name(states[i]));
      HAL_UART_Transmit(&huart4, (uint8_t*)buf, n, 50);
    }
    
    // Count valid vs invalid
    int valid = 0;
    for (int i = 0; i < count; i++) {
      if (states[i] >= 1 && states[i] <= 6) valid++;
    }
    n = snprintf(buf, sizeof(buf), "Valid: %d/%d (%.1f%%)\r\n", valid, count, 100.0f * valid / count);
    HAL_UART_Transmit(&huart4, (uint8_t*)buf, n, 50);
    return;
  }
  if (strcasecmp(s, "STATUS") == 0) {
    // print safety values and state
    char buf[200];
    // sample once to update readings
    safety_sample_once();
    uint32_t raw_v = safety_get_last_raw_vbus();
    uint32_t raw_s = safety_get_last_raw_shunt();
    uint32_t raw_t = safety_get_last_raw_temp();
    int32_t c = safety_get_motor_current_mA();
    float v = safety_get_driver_voltage_v();
    uint16_t t = safety_get_temperature_c();
    int safe = safety_get_safe_flag();
    snprintf(buf, sizeof(buf), "STATUS: V=%.2fV I=%ldmA T=%uc | RAW: VBUS=%lu SHUNT=%lu TEMP=%lu | SAFE=%s\r\n",
             v, (long)c, (unsigned)t, (unsigned long)raw_v, (unsigned long)raw_s, (unsigned long)raw_t, safe?"YES":"NO");
    HAL_UART_Transmit(&huart4, (uint8_t*)buf, strlen(buf), 100);
    return;
  }
  if (strcasecmp(s, "FRAME") == 0) {
    // print stored frame once
    if (!frame_store_has()) {
      HAL_UART_Transmit(&huart4, (uint8_t*)"FRAME: <none>\r\n", 16, 50);
      return;
    }
    uint8_t bufdata[128];
    size_t len = frame_store_get(bufdata, sizeof(bufdata));
    HAL_UART_Transmit(&huart4, (uint8_t*)"FRAME:\r\n", 8, 50);
    // print hex inline
    for (size_t i = 0; i < len; ++i) {
      char s2[4];
      snprintf(s2, sizeof(s2), "%02X", bufdata[i]);
      HAL_UART_Transmit(&huart4, (uint8_t*)s2, 2, 50);
      if (i + 1 < len) HAL_UART_Transmit(&huart4, (uint8_t*)" ", 1, 20);
    }
    HAL_UART_Transmit(&huart4, (uint8_t*)"\r\n", 2, 50);
    return;
  }
  if (strncasecmp(s, "FRAME RAW", 9) == 0) {
    if (!frame_store_has()) {
      HAL_UART_Transmit(&huart4, (uint8_t*)"FRAME LEN: 0\r\nCHECKSUM: N/A\r\nDATA:\r\n\r\n", 36, 50);
      return;
    }
    uint8_t bufdata[128];
    size_t len = frame_store_get(bufdata, sizeof(bufdata));
    // compute SUM checksum over all but last byte and compare to last
    int chk_ok = 0;
    if (len >= 1) {
      uint8_t sum = 0;
      for (size_t i = 0; i + 1 < len; ++i) sum += bufdata[i];
      if (sum == bufdata[len-1]) chk_ok = 1;
    }
    char hdr[64];
    snprintf(hdr, sizeof(hdr), "FRAME LEN: %lu\r\nCHECKSUM: %s\r\nDATA:\r\n", (unsigned long)len, chk_ok?"OK":"FAIL");
    HAL_UART_Transmit(&huart4, (uint8_t*)hdr, strlen(hdr), 100);
    for (size_t i = 0; i < len; ++i) {
      char s2[4];
      snprintf(s2, sizeof(s2), "%02X", bufdata[i]);
      HAL_UART_Transmit(&huart4, (uint8_t*)s2, 2, 50);
      if (i + 1 < len) HAL_UART_Transmit(&huart4, (uint8_t*)" ", 1, 20);
    }
    HAL_UART_Transmit(&huart4, (uint8_t*)"\r\n", 2, 50);
    return;
  }
  if (strcasecmp(s, "STOP") == 0 || strcasecmp(s, "DISARM") == 0) {
    esc_disarm();
    return;
  }
  if (strncasecmp(s, "BYPASS", 6) == 0) {
    const char* p = s + 6;
    while (*p == ' ') ++p;
    if (strcasecmp(p, "ON") == 0) {
      safety_set_bypass(1);
      HAL_UART_Transmit(&huart4, (uint8_t*)"SAFETY BYPASS ENABLED\r\n", 23, 50);
      return;
    } else if (strcasecmp(p, "OFF") == 0) {
      safety_set_bypass(0);
      HAL_UART_Transmit(&huart4, (uint8_t*)"SAFETY BYPASS DISABLED\r\n", 24, 50);
      return;
    }
  }
  if (strncasecmp(s, "THROTTLE", 8) == 0) {
    const char* p = s + 8;
    while (*p == ' ') ++p;
    int throttle = atoi(p);
    esc_set_throttle(throttle);
    uart_commands_reset_watchdog();
    
    // Print feedback
    char buf[80];
    int percent = (throttle > 100) ? ((throttle * 100) / 1000) : throttle;
    int n = snprintf(buf, sizeof(buf), "THROTTLE: %d%% (raw=%d)\r\n", percent, throttle);
    HAL_UART_Transmit(&huart4, (uint8_t*)buf, n, 50);
    return;
  }
  if (strcasecmp(s, "SPEED") == 0) {
    // SPEED is an alias for THROTTLE (for semantic clarity)
    // Just treat as PWM / throttle command
    // Example: SPEED 50 means 50% throttle
    esc_set_throttle(50);  // Default to middle throttle on SPEED command
    uart_commands_reset_watchdog();
    HAL_UART_Transmit(&huart4, (uint8_t*)"SPEED: 50% idle\r\n", 20, 50);
    return;
  }
  if (strncasecmp(s, "PWM", 3) == 0) {
    const char* p = s + 3;
    while (*p == ' ') ++p;
    int pwm = atoi(p);
    esc_set_pwm_percent(pwm);
    // Reset watchdog timer for bypass mode
    uart_commands_reset_watchdog();
    char buf[40];
    int n = snprintf(buf, sizeof(buf), "PWM: %d%%\r\n", pwm);
    HAL_UART_Transmit(&huart4, (uint8_t*)buf, n, 50);
    return;
  }
  if (strcasecmp(s, "START") == 0) {
    // START is deprecated - use ARM + THROTTLE instead
    HAL_UART_Transmit(&huart4, (uint8_t*)"Use ARM then THROTTLE <value>\r\n", 32, 50);
    return;
  }
  if (strncasecmp(s, "PULSE", 5) == 0) {
    // Test single-phase pulse: PULSE A 50
    const char* p = s + 5;
    while (*p == ' ') ++p;
    char phase = *p;
    p++;
    while (*p == ' ') ++p;
    int duty = atoi(p);
    if (duty < 0) duty = 0;
    if (duty > 100) duty = 100;
    
    // PULSE command is deprecated - Hall sensors now handle commutation
    HAL_UART_Transmit(&huart4, (uint8_t*)"PULSE: command deprecated (Hall sensors control commutation)\r\n", 65, 50);
    return;
  }
  if (strncasecmp(s, "SPD", 3) == 0) {
    const char* p = s + 3;
    while (*p == ' ') ++p;
    int rpm = atoi(p);
    esc_set_speed_rpm(rpm);
    return;
  }
  if (strncasecmp(s, "TRQ", 3) == 0) {
    const char* p = s + 3;
    while (*p == ' ') ++p;
    int mA = atoi(p);
    esc_set_torque_mA(mA);
    return;
  }
  
  // TEST command: Manual phase control for debugging
  if (strncasecmp(s, "TEST", 4) == 0) {
    const char* p = s + 4;
    while (*p == ' ') ++p;
    
    // Read Hall pins and show raw state
    if (strncasecmp(p, "HALL_DEBUG", 10) == 0) {
      uint8_t hall = hall_sensor_read();
      // Read raw GPIO pins directly
      GPIO_PinState u = HAL_GPIO_ReadPin(GPIOC, GPIO_PIN_0);
      GPIO_PinState v = HAL_GPIO_ReadPin(GPIOC, GPIO_PIN_1);
      GPIO_PinState w = HAL_GPIO_ReadPin(GPIOC, GPIO_PIN_2);
      char buf[100];
      snprintf(buf, sizeof(buf), 
        "HALL_RAW: PC0=%d PC1=%d PC2=%d | State=0x%X (%s)\r\n",
        u, v, w, hall, hall_sensor_state_name(hall));
      HAL_UART_Transmit(&huart4, (uint8_t*)buf, strlen(buf), 50);
      return;
    }
    
    // TEST PHASE: manually apply a specific Hall pattern
    if (strncasecmp(p, "PHASE", 5) == 0) {
      p += 5;
      while (*p == ' ') ++p;
      int pattern = atoi(p);  // 0-6 for Hall states
      if (pattern < 0 || pattern > 6) pattern = 0;
      
      driver_enable();
      int duty = 400;  // 50% duty with dead-time protection
      driver_set_phase_pwm((uint8_t)pattern, (int16_t)duty);
      
      char buf[80];
      snprintf(buf, sizeof(buf), "TEST_PHASE: Applied 0x%X duty=%d\r\n", pattern, duty);
      HAL_UART_Transmit(&huart4, (uint8_t*)buf, strlen(buf), 50);
      return;
    }
    
    // TEST PWM_DIRECT: Output PWM directly on U phase pin (PA8/TIM1_CH1) only
    if (strncasecmp(p, "PWM_DIRECT", 10) == 0) {
      driver_enable();
      // Set U phase to 50% duty, V/W to 0
      driver_set_pwm_u(420);  // 50% of 840
      driver_set_pwm_v(0);
      driver_set_pwm_w(0);
      HAL_UART_Transmit(&huart4, (uint8_t*)"TEST: 50% PWM on U phase (PA8)\r\n", 33, 50);
      return;
    }
    
    // TEST OFF: Stop all PWM
    if (strncasecmp(p, "OFF", 3) == 0) {
      driver_set_pwm_u(0);
      driver_set_pwm_v(0);
      driver_set_pwm_w(0);
      HAL_UART_Transmit(&huart4, (uint8_t*)"TEST: All PWM off\r\n", 19, 50);
      return;
    }
    
    // TEST SWEEP: Try each of 6-step patterns continuously
    if (strncasecmp(p, "SWEEP", 5) == 0) {
      driver_enable();
      const uint8_t patterns[] = {0x1, 0x3, 0x2, 0x6, 0x4, 0x5};
      
      HAL_UART_Transmit(&huart4, (uint8_t*)"TEST SWEEP: Cycling through 6-step patterns...\r\n", 49, 50);
      HAL_UART_Transmit(&huart4, (uint8_t*)"Send THROTTLE 0 or DISARM to stop\r\n", 37, 50);
      
      for (int i = 0; i < 30; i++) {  // 30 cycles = 5 seconds @ 6Hz
        uint8_t pattern = patterns[i % 6];
        driver_set_phase_pwm(pattern, 400);  // 50% duty with dead-time protection
        
        char buf[100];
        snprintf(buf, sizeof(buf), "  Step %d: Pattern 0x%X\r\n", i % 6, pattern);
        HAL_UART_Transmit(&huart4, (uint8_t*)buf, strlen(buf), 50);
        
        // Brief delay between steps
        for (int j = 0; j < 100; j++) {
          IWDG->KR = 0xAAAA;  // Feed watchdog
          delay(10);
        }
      }
      
      driver_set_pwm_u(0);
      driver_set_pwm_v(0);
      driver_set_pwm_w(0);
      HAL_UART_Transmit(&huart4, (uint8_t*)"SWEEP complete\r\n", 17, 50);
      return;
    }
    
    // TEST SINGLE: Test individual phases U, V, W
    if (strncasecmp(p, "SINGLE", 6) == 0) {
      p += 6;
      while (*p == ' ') ++p;
      char phase = *p;
      
      driver_enable();
      int duty = 400;  // 50% duty with proper dead-time
      
      driver_set_pwm_u(0);
      driver_set_pwm_v(0);
      driver_set_pwm_w(0);
      
      if (phase == 'U' || phase == 'u') {
        driver_set_pwm_u(duty);
        HAL_UART_Transmit(&huart4, (uint8_t*)"TEST: U phase ON (PA8)\r\n", 24, 50);
      } else if (phase == 'V' || phase == 'v') {
        driver_set_pwm_v(duty);
        HAL_UART_Transmit(&huart4, (uint8_t*)"TEST: V phase ON (PA9)\r\n", 24, 50);
      } else if (phase == 'W' || phase == 'w') {
        driver_set_pwm_w(duty);
        HAL_UART_Transmit(&huart4, (uint8_t*)"TEST: W phase ON (PA10)\r\n", 25, 50);
      } else {
        HAL_UART_Transmit(&huart4, (uint8_t*)"Usage: TEST SINGLE U|V|W\r\n", 27, 50);
      }
      return;
    }
    return;
  }
  
  // HELP command
  if (strcasecmp(s, "HELP") == 0 || strcasecmp(s, "H") == 0) {
    HAL_UART_Transmit(&huart4, (uint8_t*)"\r\n=== ESC DRONE CONTROL ===\r\n", 29, 50);
    HAL_UART_Transmit(&huart4, (uint8_t*)"a            - ARM\r\n", 19, 50);
    HAL_UART_Transmit(&huart4, (uint8_t*)"s            - STOP/DISARM\r\n", 28, 50);
    HAL_UART_Transmit(&huart4, (uint8_t*)"t <0-100>   - THROTTLE (e.g., t50 for 50%)\r\n", 44, 50);
    HAL_UART_Transmit(&huart4, (uint8_t*)"STATUS      - Show voltage/current/temp\r\n", 41, 50);
    HAL_UART_Transmit(&huart4, (uint8_t*)"HALL        - Show hall sensor state\r\n", 38, 50);
    HAL_UART_Transmit(&huart4, (uint8_t*)"\r\n", 2, 50);
    return;
  }
  
  // unknown notthing happens 
  
}

int uart_commands_feed(uint8_t b) {
  if (b == '\r') return 0; // ignore
  if (b == '\n') {
    cmd_buf[cmd_pos] = '\0';
    if (cmd_pos > 0) process_command(cmd_buf);
    cmd_pos = 0;
    last_cmd_ms = HAL_GetTick();
    return 1;
  }
  if (cmd_pos + 1 < sizeof(cmd_buf)) {
    cmd_buf[cmd_pos++] = (char)b;
  } else {
    // overflow, reset
    cmd_pos = 0;
  }
  return 0;
}

uint32_t uart_commands_last_seen_ms(void) {
  return last_cmd_ms;
}

void uart_commands_reset_watchdog(void) {
  last_cmd_ms = HAL_GetTick();
}
