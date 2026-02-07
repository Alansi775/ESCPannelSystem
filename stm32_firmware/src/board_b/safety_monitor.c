#include "safety_monitor.h"
#include "safety_monitor.h"
#include "safety_params.h"
#include "stm32f4xx_hal.h"
#include <stdio.h>
#include <stdlib.h>

// ADC pins and channels (change to match your hardware wiring)
#define VBUS_ADC_GPIO_PORT GPIOA
#define VBUS_ADC_PIN GPIO_PIN_0
#define VBUS_ADC_CHANNEL ADC_CHANNEL_0

#define SHUNT_ADC_GPIO_PORT GPIOA
#define SHUNT_ADC_PIN GPIO_PIN_1
#define SHUNT_ADC_CHANNEL ADC_CHANNEL_1

#define TEMP_ADC_GPIO_PORT GPIOA
#define TEMP_ADC_PIN GPIO_PIN_2
#define TEMP_ADC_CHANNEL ADC_CHANNEL_2

static ADC_HandleTypeDef hadc1;
static uint32_t last_raw_vbus = 0;
static uint32_t last_raw_shunt = 0;
static uint32_t last_raw_temp = 0;
static uint32_t last_vbus_mv = 0;
static int32_t last_current_ma = 0;
static uint16_t last_temp_c = 25;
static int calibrate_mode = 0;
static int temp_valid = 0;
static int current_valid = 0;
static int bypass_printed = 0;
static int sensor_bypass = 1;

// calibration averaging
static uint32_t cal_start_ms = 0;
static uint64_t cal_shunt_sum = 0;
static uint32_t cal_shunt_count = 0;
static uint32_t cal_offset_raw = 0;
static int cal_offset_ready = 0;

static uint32_t adc_max = ((1u << SAFETY_ADC_RESOLUTION_BITS) - 1u);

static int adc_valid(uint16_t v) {
  return (v > 20 && v < 4000);
}

static void MX_ADC1_Init(void) {
  __HAL_RCC_ADC1_CLK_ENABLE();
  ADC_ChannelConfTypeDef sConfig = {0};

  hadc1.Instance = ADC1;
  hadc1.Init.ClockPrescaler = ADC_CLOCK_SYNC_PCLK_DIV4;
  hadc1.Init.Resolution = (SAFETY_ADC_RESOLUTION_BITS == 12) ? ADC_RESOLUTION_12B : ADC_RESOLUTION_12B;
  hadc1.Init.ScanConvMode = DISABLE;
  hadc1.Init.ContinuousConvMode = DISABLE;
  hadc1.Init.DiscontinuousConvMode = DISABLE;
  hadc1.Init.ExternalTrigConvEdge = ADC_EXTERNALTRIGCONVEDGE_NONE;
  hadc1.Init.ExternalTrigConv = ADC_SOFTWARE_START;
  hadc1.Init.DataAlign = ADC_DATAALIGN_RIGHT;
  hadc1.Init.NbrOfConversion = 1;
  hadc1.Init.DMAContinuousRequests = DISABLE;
  hadc1.Init.EOCSelection = ADC_EOC_SINGLE_CONV;
  HAL_ADC_Init(&hadc1);
}

static uint32_t adc_sample_channel(uint32_t channel) {
  ADC_ChannelConfTypeDef sConfig = {0};
  sConfig.Channel = channel;
  sConfig.Rank = 1;
  sConfig.SamplingTime = ADC_SAMPLETIME_56CYCLES;
  if (HAL_ADC_ConfigChannel(&hadc1, &sConfig) != HAL_OK) return 0;
  HAL_ADC_Start(&hadc1);
  if (HAL_ADC_PollForConversion(&hadc1, 20) == HAL_OK) {
    uint32_t v = HAL_ADC_GetValue(&hadc1);
    HAL_ADC_Stop(&hadc1);
    return v;
  }
  HAL_ADC_Stop(&hadc1);
  return 0;
}

void safety_monitor_init(void) {
  // configure GPIOs for analog
  __HAL_RCC_GPIOA_CLK_ENABLE();
  GPIO_InitTypeDef gpio = {0};
  gpio.Pin = VBUS_ADC_PIN | SHUNT_ADC_PIN | TEMP_ADC_PIN;
  gpio.Mode = GPIO_MODE_ANALOG;
  gpio.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOA, &gpio);

  MX_ADC1_Init();

  // initial sample
  safety_sample_once();
  
  // print sensor bypass message once at boot
  if (!bypass_printed) {
    bypass_printed = 1;
    extern UART_HandleTypeDef huart4;
    HAL_UART_Transmit(&huart4, (uint8_t*)"SENSOR BYPASS ACTIVE\r\n", 22, 50);
  }
}

void safety_sample_once(void) {
  uint32_t v_vbus = adc_sample_channel(VBUS_ADC_CHANNEL);
  uint32_t v_shunt = adc_sample_channel(SHUNT_ADC_CHANNEL);
  uint32_t v_temp = adc_sample_channel(TEMP_ADC_CHANNEL);

  last_raw_vbus = v_vbus;
  last_raw_shunt = v_shunt;
  last_raw_temp = v_temp;

  float vbus_volts = ((float)v_vbus / (float)adc_max) * SAFETY_ADC_REF_VOLTAGE * SAFETY_VBUS_DIVIDER;
  last_vbus_mv = (uint32_t)(vbus_volts * 1000.0f + 0.5f);

  // Check current sensor validity
  if (!adc_valid(v_shunt)) {
    last_current_ma = 0;
    current_valid = 0;
  } else {
    float v_shunt_volts = ((float)v_shunt / (float)adc_max) * SAFETY_ADC_REF_VOLTAGE;
    float shunt_ohms = (SAFETY_SHUNT_MOHMS / 1000.0f);
    float current_a = 0.0f;
    if (cal_offset_ready) {
      // convert using offset-corrected ADC raw
      int32_t raw_corr = (int32_t)v_shunt - (int32_t)cal_offset_raw;
      float v_shunt_corr = ((float)raw_corr / (float)adc_max) * SAFETY_ADC_REF_VOLTAGE;
      current_a = v_shunt_corr / (shunt_ohms * SAFETY_SHUNT_AMP_GAIN);
    } else {
      current_a = v_shunt_volts / (shunt_ohms * SAFETY_SHUNT_AMP_GAIN);
    }
    last_current_ma = (int32_t)(current_a * 1000.0f + 0.5f);
    current_valid = 1;
  }

  // Check temperature sensor validity
  if (!adc_valid(v_temp)) {
    last_temp_c = 25;
    temp_valid = 0;
  } else {
    float temp_volts = ((float)v_temp / (float)adc_max) * SAFETY_ADC_REF_VOLTAGE;
    last_temp_c = (uint16_t)( (temp_volts * 1000.0f) / SAFETY_TEMP_MV_PER_DEG + 0.5f );
    temp_valid = 1;
  }

  // calibration handling
  if (calibrate_mode) {
    uint32_t now = HAL_GetTick();
    // accumulate shunt raw for offset during first SAFETY_CAL_AVG_MS
    if (cal_start_ms == 0) {
      cal_start_ms = now;
      cal_shunt_sum = 0;
      cal_shunt_count = 0;
      cal_offset_ready = 0;
      // ensure driver is disabled during calibration
      driver_disable();
    }
    cal_shunt_sum += v_shunt;
    cal_shunt_count++;

    if (!cal_offset_ready && (now - cal_start_ms) >= SAFETY_CAL_AVG_MS) {
      cal_offset_raw = (uint32_t)(cal_shunt_sum / (cal_shunt_count ? cal_shunt_count : 1));
      cal_offset_ready = 1;
      // announce offset
      extern UART_HandleTypeDef huart4;
      char buf[80];
      int n = snprintf(buf, sizeof(buf), "CAL: offset_raw=%lu\r\n", (unsigned long)cal_offset_raw);
      HAL_UART_Transmit(&huart4, (uint8_t*)buf, n, 50);
    }

    // print at configured interval
    static uint32_t last_print = 0;
    if ((HAL_GetTick() - last_print) >= SAFETY_CAL_PRINT_MS) {
      last_print = HAL_GetTick();
      extern UART_HandleTypeDef huart4;
      char buf[160];
      int n = snprintf(buf, sizeof(buf), "ADC RAW: VBUS=%lu SHUNT=%lu TEMP=%lu | Vbus_mv=%lu mV Curr_ma=%ld mA Temp_c=%u\r\n",
                       (unsigned long)v_vbus, (unsigned long)v_shunt, (unsigned long)v_temp,
                       (unsigned long)last_vbus_mv, (long)last_current_ma, (unsigned)last_temp_c);
      HAL_UART_Transmit(&huart4, (uint8_t*)buf, n, 100);
    }
  } else {
    // reset calibration state when not calibrating
    cal_start_ms = 0;
    cal_shunt_sum = 0;
    cal_shunt_count = 0;
  }
}

void safety_enable_calibration(int enable) {
  if (enable) {
    calibrate_mode = 1;
    cal_start_ms = 0;
    cal_shunt_sum = 0;
    cal_shunt_count = 0;
    cal_offset_ready = 0;
    // force driver off
    driver_disable();
  } else {
    calibrate_mode = 0;
  }
}

int safety_is_calibrating(void) { return calibrate_mode; }

uint32_t safety_get_last_raw_vbus(void) { return last_raw_vbus; }
uint32_t safety_get_last_raw_shunt(void) { return last_raw_shunt; }
uint32_t safety_get_last_raw_temp(void) { return last_raw_temp; }

void safety_set_bypass(int enable) {
  sensor_bypass = enable ? 1 : 0;
}

int safety_get_bypass(void) {
  return sensor_bypass;
}

int safety_get_safe_flag(void) {
  // If sensor bypass is active, always return SAFE (for bring-up testing)
  if (sensor_bypass) {
    return 1;
  }
  // Determine SAFE: VBUS in reasonable range (> 2V), current near zero if valid (abs < 50mA), temp reasonable if valid (<85C), driver disabled
  safety_sample_once();
  int safe = 1;
  if (last_vbus_mv < 2000) safe = 0;
  // Only check current fault if current sensor is valid
  if (current_valid && abs(last_current_ma) > 50) safe = 0;
  // Only check temperature fault if temperature sensor is valid
  if (temp_valid && last_temp_c > 85) safe = 0;
  // driver status: if enabled, not safe
  if (driver_is_enabled()) safe = 0;
  return safe;
}

int32_t safety_get_motor_current_mA(void) {
  safety_sample_once();
  return last_current_ma;
}

float safety_get_driver_voltage_v(void) {
  safety_sample_once();
  return ((float)last_vbus_mv) / 1000.0f;
}

uint16_t safety_get_temperature_c(void) {
  safety_sample_once();
  // When bypass is enabled, return nominal temp to disable temperature protection
  extern int safety_get_bypass(void);
  if (safety_get_bypass()) {
    return 25;
  }
  return last_temp_c;
}

