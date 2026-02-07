#include "hall_sensor.h"
#include "stm32f4xx_hal.h"

// Hall sensor pins: PC0, PC1, PC2
#define HALL_PORT GPIOC
#define HALL_U_PIN GPIO_PIN_0
#define HALL_V_PIN GPIO_PIN_1
#define HALL_W_PIN GPIO_PIN_2

static hall_callback_t user_callback = NULL;
static uint8_t last_hall_state = 0;

void hall_sensor_init(void) {
  __HAL_RCC_GPIOC_CLK_ENABLE();
  
  GPIO_InitTypeDef gpio = {0};
  gpio.Pin = HALL_U_PIN | HALL_V_PIN | HALL_W_PIN;
  gpio.Mode = GPIO_MODE_INPUT;
  gpio.Pull = GPIO_PULLUP;
  gpio.Speed = GPIO_SPEED_FREQ_HIGH;
  
  HAL_GPIO_Init(HALL_PORT, &gpio);
  
  last_hall_state = hall_sensor_read();
}

uint8_t hall_sensor_read(void) {
  uint8_t state = 0;
  
  if (HAL_GPIO_ReadPin(HALL_PORT, HALL_U_PIN) == GPIO_PIN_SET) state |= 0x01;
  if (HAL_GPIO_ReadPin(HALL_PORT, HALL_V_PIN) == GPIO_PIN_SET) state |= 0x02;
  if (HAL_GPIO_ReadPin(HALL_PORT, HALL_W_PIN) == GPIO_PIN_SET) state |= 0x04;
  
  // Check for state change and call callback
  if (state != last_hall_state) {
    last_hall_state = state;
    if (user_callback) {
      user_callback(state);
    }
  }
  
  return state;
}

const char* hall_sensor_state_name(uint8_t state) {
  // Standard BLDC Hall patterns (out of 8 possible states, only 6 are valid)
  switch (state) {
    case 0x5: return "H5 (A+B-)";   // 101
    case 0x1: return "H1 (A+C-)";   // 001
    case 0x3: return "H3 (B+C-)";   // 011
    case 0x2: return "H2 (B+A-)";   // 010
    case 0x6: return "H6 (C+A-)";   // 110
    case 0x4: return "H4 (C+B-)";   // 100
    default: return "INVALID";
  }
}

void hall_sensor_set_callback(hall_callback_t cb) {
  user_callback = cb;
}
