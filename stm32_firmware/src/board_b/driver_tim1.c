#include "driver_tim1.h"
#include "stm32f4xx_hal.h"

extern UART_HandleTypeDef huart4;

static TIM_HandleTypeDef htim1;
static int driver_enabled = 0;

// Wrapper for compatibility with old code
void driver_init(void) {
  driver_init_tim1();
}

void driver_init_tim1(void) {
  __HAL_RCC_TIM1_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();
  
  // Configure PA8, PA9, PA10 as PWM outputs (TIM1_CH1/2/3)
  GPIO_InitTypeDef gpio = {0};
  gpio.Pin = GPIO_PIN_8 | GPIO_PIN_9 | GPIO_PIN_10;
  gpio.Mode = GPIO_MODE_AF_PP;
  gpio.Pull = GPIO_NOPULL;
  gpio.Speed = GPIO_SPEED_FREQ_HIGH;
  gpio.Alternate = GPIO_AF1_TIM1;
  HAL_GPIO_Init(GPIOA, &gpio);
  
  // Configure PB13, PB14, PB15 as complementary PWM outputs (TIM1_CH1N/2N/3N)
  gpio.Pin = GPIO_PIN_13 | GPIO_PIN_14 | GPIO_PIN_15;
  HAL_GPIO_Init(GPIOB, &gpio);
  
  // Timer configuration
  htim1.Instance = TIM1;
  htim1.Init.Prescaler = 0;  // No prescaler, 84 MHz from APB2
  htim1.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim1.Init.Period = 1680 - 1;  // 50 kHz PWM (84MHz / 1680 = 50kHz, smoother for gate drivers)
  htim1.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim1.Init.RepetitionCounter = 0;
  htim1.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_ENABLE;
  
  HAL_TIM_PWM_Init(&htim1);
  
  // Configure dead-time: 3 microseconds (~252 ticks at 84MHz) to prevent shoot-through
  TIM_BreakDeadTimeConfigTypeDef sBreakDeadTimeConfig = {0};
  sBreakDeadTimeConfig.OffStateRunMode = TIM_OSSR_ENABLE;
  sBreakDeadTimeConfig.OffStateIDLEMode = TIM_OSSI_ENABLE;
  sBreakDeadTimeConfig.LockLevel = TIM_LOCKLEVEL_OFF;
  sBreakDeadTimeConfig.DeadTime = 252;  // 3 microseconds dead-time (safer for gate drivers)
  sBreakDeadTimeConfig.BreakState = TIM_BREAK_DISABLE;
  sBreakDeadTimeConfig.BreakPolarity = TIM_BREAKPOLARITY_HIGH;
  sBreakDeadTimeConfig.AutomaticOutput = TIM_AUTOMATICOUTPUT_ENABLE;
  
  HAL_TIMEx_ConfigBreakDeadTime(&htim1, &sBreakDeadTimeConfig);
  
  // Configure all 3 channels for complementary PWM
  TIM_OC_InitTypeDef sConfigOC = {0};
  sConfigOC.OCMode = TIM_OCMODE_PWM1;
  sConfigOC.Pulse = 0;
  sConfigOC.OCPolarity = TIM_OCPOLARITY_HIGH;
  sConfigOC.OCNPolarity = TIM_OCNPOLARITY_HIGH;
  sConfigOC.OCFastMode = TIM_OCFAST_DISABLE;
  sConfigOC.OCIdleState = TIM_OCIDLESTATE_RESET;
  sConfigOC.OCNIdleState = TIM_OCNIDLESTATE_RESET;
  
  HAL_TIM_PWM_ConfigChannel(&htim1, &sConfigOC, TIM_CHANNEL_1);
  HAL_TIM_PWM_ConfigChannel(&htim1, &sConfigOC, TIM_CHANNEL_2);
  HAL_TIM_PWM_ConfigChannel(&htim1, &sConfigOC, TIM_CHANNEL_3);
  
  driver_enabled = 0;
  
  HAL_UART_Transmit(&huart4, (uint8_t*)"TIM1 Complementary PWM initialized (50 kHz, dead-time=3us)\r\n", 61, 50);
}

void driver_enable(void) {
  if (driver_enabled) return;
  
  // Start PWM channels with complementary outputs
  HAL_TIM_PWM_Start(&htim1, TIM_CHANNEL_1);
  HAL_TIMEx_PWMN_Start(&htim1, TIM_CHANNEL_1);
  
  HAL_TIM_PWM_Start(&htim1, TIM_CHANNEL_2);
  HAL_TIMEx_PWMN_Start(&htim1, TIM_CHANNEL_2);
  
  HAL_TIM_PWM_Start(&htim1, TIM_CHANNEL_3);
  HAL_TIMEx_PWMN_Start(&htim1, TIM_CHANNEL_3);
  
  // Start main timer counter
  HAL_TIM_Base_Start(&htim1);
  
  driver_enabled = 1;
  HAL_UART_Transmit(&huart4, (uint8_t*)"DRIVER: ENABLED (TIM1 Complementary PWM)\r\n", 43, 50);
}

void driver_disable(void) {
  if (!driver_enabled) return;
  
  // Stop PWM channels
  HAL_TIM_PWM_Stop(&htim1, TIM_CHANNEL_1);
  HAL_TIMEx_PWMN_Stop(&htim1, TIM_CHANNEL_1);
  
  HAL_TIM_PWM_Stop(&htim1, TIM_CHANNEL_2);
  HAL_TIMEx_PWMN_Stop(&htim1, TIM_CHANNEL_2);
  
  HAL_TIM_PWM_Stop(&htim1, TIM_CHANNEL_3);
  HAL_TIMEx_PWMN_Stop(&htim1, TIM_CHANNEL_3);
  
  HAL_TIM_Base_Stop(&htim1);
  
  driver_enabled = 0;
  HAL_UART_Transmit(&huart4, (uint8_t*)"DRIVER: DISABLED (TIM1)\r\n", 26, 50);
}

int driver_is_enabled(void) {
  return driver_enabled;
}

void driver_set_phase_pwm(uint8_t hall_state, int16_t duty) {
  if (!driver_enabled || duty < 0) {
    // All phases off
    __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_1, 0);
    __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_2, 0);
    __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_3, 0);
    return;
  }
  
  if (duty > 1680) duty = 1680;  // New period = 1680 (50 kHz)
  
  // Apply commutation pattern based on Hall state
  // Each Hall state activates one phase pair
  switch (hall_state) {
    case 0x5: // H5: U+ V- (activate U and GND V)
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_1, duty);  // U = PWM
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_2, 0);      // V = GND
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_3, 0);      // W = float
      break;
      
    case 0x1: // H1: U+ W- 
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_1, duty);  // U = PWM
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_2, 0);      // V = float
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_3, 0);      // W = GND
      break;
      
    case 0x3: // H3: V+ W-
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_1, 0);      // U = float
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_2, duty);  // V = PWM
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_3, 0);      // W = GND
      break;
      
    case 0x2: // H2: V+ U-
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_1, 0);      // U = GND
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_2, duty);  // V = PWM
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_3, 0);      // W = float
      break;
      
    case 0x6: // H6: W+ U-
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_1, 0);      // U = GND
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_2, 0);      // V = float
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_3, duty);  // W = PWM
      break;
      
    case 0x4: // H4: W+ V-
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_1, 0);      // U = float
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_2, 0);      // V = GND
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_3, duty);  // W = PWM
      break;
      
    default: // Invalid state, turn off
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_1, 0);
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_2, 0);
      __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_3, 0);
  }
}

// Direct PWM setters for testing (0-1680 scale with new 50kHz period)
void driver_set_pwm_u(int16_t duty) {
  if (duty < 0) duty = 0;
  if (duty > 1680) duty = 1680;
  __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_1, duty);
}

void driver_set_pwm_v(int16_t duty) {
  if (duty < 0) duty = 0;
  if (duty > 1680) duty = 1680;
  __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_2, duty);
}

void driver_set_pwm_w(int16_t duty) {
  if (duty < 0) duty = 0;
  if (duty > 1680) duty = 1680;
  __HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_3, duty);
}
