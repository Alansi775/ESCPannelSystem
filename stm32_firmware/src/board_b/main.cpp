#include <Arduino.h>
#include <vector>
#include "stm32f4xx.h"
#include "stm32f4xx_hal.h"
#include "config_parser.h"
#include "esc_control.h"
#include "safety_monitor.h"
#include "uart_commands.h"
#include "driver_tim1.h"
#include "hall_sensor.h"
#include "safety_params.h"

UART_HandleTypeDef huart4;

// Buffer and state for receiving frames over UART4
static std::vector<uint8_t> frame_buf;
static bool in_frame = false;
static std::vector<uint8_t> stored_data;
static bool has_stored = false;
volatile static uint32_t rx_count = 0;

// Expose stored frame via C API for other modules (read-only copy)
extern "C" size_t frame_store_get(uint8_t* buf, size_t maxlen) {
  if (!has_stored) return 0;
  size_t n = stored_data.size();
  if (buf && maxlen > 0) {
    size_t copy = (n < maxlen) ? n : maxlen;
    for (size_t i = 0; i < copy; ++i) buf[i] = stored_data[i];
  }
  return n;
}

extern "C" int frame_store_has(void) {
  return has_stored ? 1 : 0;
}

// Flash storage configuration (same approach used by board_a)
#define FLASH_STORAGE_BASE 0x08060000UL
#define FLASH_MAGIC 0xDEADBEEFUL
#define FLASH_MAX_BYTES (128 * 1024)

static bool flash_erase_sector7() {
  HAL_FLASH_Unlock();
  FLASH_EraseInitTypeDef EraseInitStruct;
  uint32_t SectorError = 0;
  EraseInitStruct.TypeErase = FLASH_TYPEERASE_SECTORS;
  EraseInitStruct.Sector = FLASH_SECTOR_7;
  EraseInitStruct.NbSectors = 1;
  EraseInitStruct.VoltageRange = FLASH_VOLTAGE_RANGE_3;
  int ret = HAL_FLASHEx_Erase(&EraseInitStruct, &SectorError);
  HAL_FLASH_Lock();
  return (ret == HAL_OK);
}

static bool flash_write_bytes(const uint8_t* data, uint32_t len) {
  if (len == 0 || len > FLASH_MAX_BYTES - 8) return false;
  if (!flash_erase_sector7()) return false;
  HAL_FLASH_Unlock();
  uint32_t addr = FLASH_STORAGE_BASE;
  if (HAL_FLASH_Program(FLASH_TYPEPROGRAM_WORD, addr, FLASH_MAGIC) != HAL_OK) { HAL_FLASH_Lock(); return false; }
  addr += 4;
  if (HAL_FLASH_Program(FLASH_TYPEPROGRAM_WORD, addr, len) != HAL_OK) { HAL_FLASH_Lock(); return false; }
  addr += 4;
  for (uint32_t i = 0; i < len; i += 4) {
    uint32_t w = 0;
    for (uint32_t b = 0; b < 4; ++b) {
      uint32_t idx = i + b;
      if (idx < len) w |= ((uint32_t)data[idx]) << (8 * b);
    }
    if (HAL_FLASH_Program(FLASH_TYPEPROGRAM_WORD, addr, w) != HAL_OK) { HAL_FLASH_Lock(); return false; }
    addr += 4;
  }
  HAL_FLASH_Lock();
  return true;
}

static bool flash_read_bytes(std::vector<uint8_t>& out) {
  uint32_t addr = FLASH_STORAGE_BASE;
  uint32_t magic = *(uint32_t*)addr;
  if (magic != FLASH_MAGIC) return false;
  addr += 4;
  uint32_t len = *(uint32_t*)addr;
  addr += 4;
  if (len == 0 || len > FLASH_MAX_BYTES - 8) return false;
  out.clear();
  out.reserve(len);
  for (uint32_t i = 0; i < len; ++i) {
    uint8_t v = *((uint8_t*)(addr + i));
    out.push_back(v);
  }
  return true;
}

// Initialize UART4 (PC10 TX, PC11 RX)
void initUART4() {
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_UART4_CLK_ENABLE();

  GPIO_InitTypeDef GPIO_InitStruct = {0};

  // TX (PC10)
  GPIO_InitStruct.Pin = GPIO_PIN_10;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
  GPIO_InitStruct.Alternate = GPIO_AF8_UART4;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

  // RX (PC11)
  GPIO_InitStruct.Pin = GPIO_PIN_11;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_OD;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
  GPIO_InitStruct.Alternate = GPIO_AF8_UART4;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

  huart4.Instance = UART4;
  huart4.Init.BaudRate = 115200;
  huart4.Init.WordLength = UART_WORDLENGTH_8B;
  huart4.Init.StopBits = UART_STOPBITS_1;
  huart4.Init.Parity = UART_PARITY_NONE;
  huart4.Init.Mode = UART_MODE_TX_RX;
  huart4.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart4.Init.OverSampling = UART_OVERSAMPLING_16;
  
  if (HAL_UART_Init(&huart4) == HAL_OK) {
    HAL_UART_Transmit(&huart4, (uint8_t*)"UART4 Ready!\r\n", 14, 100);
  }
}

// Utility: print hex dump of buffer to UART4
void print_hex(const uint8_t* buf, size_t len) {
  char s[4];
  const char hex[] = "0123456789ABCDEF";
  
  for (size_t i = 0; i < len; ++i) {
    s[0] = hex[(buf[i] >> 4) & 0xF];
    s[1] = hex[buf[i] & 0xF];
    s[2] = ' ';
    HAL_UART_Transmit(&huart4, (uint8_t*)s, 3, 50);
  }
  HAL_UART_Transmit(&huart4, (uint8_t*)"\r\n", 2, 50);
}

// Handle received bytes and detect frames
void handle_received_byte(uint8_t b) {
  rx_count++;
  
  if (!in_frame) {
    if (b == 0xAA) {
      in_frame = true;
      frame_buf.clear();
      frame_buf.push_back(b);
    }
  } else {
    frame_buf.push_back(b);
    const size_t EXPECTED_FRAME_LEN = 29;
    
    if (frame_buf.size() >= 2) {
      if (frame_buf[0] != 0xAA || frame_buf[1] != 0x55) {
        in_frame = false;
        frame_buf.clear();
      } else if (frame_buf.size() >= EXPECTED_FRAME_LEN) {
          bool need_store = true;
          if (has_stored && stored_data.size() == frame_buf.size()) {
            bool same = true;
            for (size_t i = 0; i < frame_buf.size(); ++i) {
              if (stored_data[i] != frame_buf[i]) { same = false; break; }
            }
            if (same) need_store = false;
          }

          if (need_store) {
            // attempt to persist to flash
            if (flash_write_bytes(frame_buf.data(), (uint32_t)frame_buf.size())) {
              stored_data = frame_buf;
              has_stored = true;
              // minimal confirmation only
              HAL_UART_Transmit(&huart4, (uint8_t*)"Frame saved\r\n", 13, 50);
            } else {
              HAL_UART_Transmit(&huart4, (uint8_t*)"Error: failed to write frame to flash\r\n", 36, 100);
            }
          }

          // do not print frame contents here to avoid UART flooding
          in_frame = false;
          frame_buf.clear();
      }
    }
  }
}

void setup() {
  HAL_Init();
  initUART4();
  
  // Welcome message
  HAL_Delay(500);
  HAL_UART_Transmit(&huart4, (uint8_t*)"\r\n", 2, 50);
  HAL_UART_Transmit(&huart4, (uint8_t*)"================================\r\n", 34, 100);
  HAL_UART_Transmit(&huart4, (uint8_t*)"  STM32 UART4 Data Receiver\r\n", 31, 100);
  HAL_UART_Transmit(&huart4, (uint8_t*)"  Waiting for data...\r\n", 24, 100);
  HAL_UART_Transmit(&huart4, (uint8_t*)"================================\r\n\r\n", 36, 100);

  // initialize safety and command parser
  safety_monitor_init();
  uart_commands_init();
  
  // Initialize Hall sensor inputs (PC0, PC1, PC2)
  hall_sensor_init();
  HAL_UART_Transmit(&huart4, (uint8_t*)"Hall sensors initialized (PC0/PC1/PC2)\r\n", 41, 50);

  // Initialize TIM1-based driver (PA8, PA9, PA10 for U/V/W phases)
  driver_init_tim1();
  driver_disable();

  // Load stored frame from flash (if present) and apply config
  esc_config_t cfg;
  if (flash_read_bytes(stored_data)) {
    has_stored = true;
    HAL_UART_Transmit(&huart4, (uint8_t*)"Frame loaded from EEPROM\r\n", 27, 100);
    if (parse_esc_config(stored_data.data(), stored_data.size(), &cfg)) {
      esc_control_init(&cfg);
      HAL_UART_Transmit(&huart4, (uint8_t*)"ESC READY\r\n", 11, 100);
      HAL_UART_Transmit(&huart4, (uint8_t*)"Commands: a(ARM) s(STOP) t<N>(THROTTLE%)\r\n", 43, 100);
      HAL_UART_Transmit(&huart4, (uint8_t*)"Type 'h' for help\r\n", 19, 100);
    } else {
      HAL_UART_Transmit(&huart4, (uint8_t*)"Failed to parse stored config\r\n", 32, 100);
    }
  } else {
    has_stored = false;
  }
}

void loop() {
  uint32_t now = HAL_GetTick();
  
  // REFRESH IWDG immediately at start of loop to prevent timeouts during blocking UART ops
  // Write 0xAAAA to the KR register to refresh the Independent Watchdog
  IWDG->KR = 0xAAAA;
  
  // Receiving data over UART4
  uint8_t rb;
  while (HAL_UART_Receive(&huart4, &rb, 1, 2) == HAL_OK) {
    handle_received_byte(rb);
    uart_commands_feed(rb);
    uart_commands_reset_watchdog();  // Feed the watchdog on each byte received
  }
  
  // Kick watchdog periodically even if no UART activity
  static uint32_t last_watchdog_kick = 0;
  if (now - last_watchdog_kick > 100) {
    last_watchdog_kick = now;
    uart_commands_reset_watchdog();  // Prevent watchdog timeout during motor operation
    IWDG->KR = 0xAAAA;  // Feed hard IWDG
  }
  
  // no periodic stored-frame printing to avoid UART flooding
  
  // ESC control periodic update (reads Hall sensors, applies commutation)
  esc_control_update();

  // If calibrating, ensure the safety monitor samples regularly (10Hz prints handled inside)
  if (safety_is_calibrating()) {
    static uint32_t last_cal_sample = 0;
    uint32_t now = HAL_GetTick();
    if (now - last_cal_sample >= SAFETY_CAL_PRINT_MS) {
      last_cal_sample = now;
      safety_sample_once();
    }
  }
  delay(1);  // Shorter delay to loop faster
}