#include <Arduino.h>
#include <string>
#include <vector>
//#include <EEPROM.h> // replaced by direct flash storage
#include "stm32f4xx.h"
#include "stm32f4xx_hal.h"
#include <cstring>

UART_HandleTypeDef huart2;

// Flash storage configuration
#define FLASH_STORAGE_BASE 0x08060000UL // sector 7 start for STM32F401RE (128KB sector)
#define FLASH_MAGIC 0xDEADBEEFUL
#define FLASH_MAX_BYTES (128 * 1024) // sector size

// Helper to erase sector 7 and write/read
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
  // write magic
  if (HAL_FLASH_Program(FLASH_TYPEPROGRAM_WORD, addr, FLASH_MAGIC) != HAL_OK) { HAL_FLASH_Lock(); return false; }
  addr += 4;
  // write length
  if (HAL_FLASH_Program(FLASH_TYPEPROGRAM_WORD, addr, len) != HAL_OK) { HAL_FLASH_Lock(); return false; }
  addr += 4;
  // write payload in 4-byte words
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

// Initialize USART2 (PA2 TX, PA3 RX) for raw transmit
void initUSART2() {
  // Enable GPIOA and USART2 clocks
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_USART2_CLK_ENABLE();

  GPIO_InitTypeDef GPIO_InitStruct = {0};
  // PA2 = TX, PA3 = RX -> AF7 for USART2
  GPIO_InitStruct.Pin = GPIO_PIN_2 | GPIO_PIN_3;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
  GPIO_InitStruct.Alternate = GPIO_AF7_USART2;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  huart2.Instance = USART2;
  huart2.Init.BaudRate = 115200;
  huart2.Init.WordLength = UART_WORDLENGTH_8B;
  huart2.Init.StopBits = UART_STOPBITS_1;
  huart2.Init.Parity = UART_PARITY_NONE;
  huart2.Init.Mode = UART_MODE_TX_RX;
  huart2.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart2.Init.OverSampling = UART_OVERSAMPLING_16;
  HAL_UART_Init(&huart2);
}

#define LED_PIN PC13

enum RxState { WAIT_H1, WAIT_H2, LEN1, LEN2, CHK, DATA, TERM };

static RxState state = WAIT_H1;
static uint16_t data_len = 0;
static uint16_t data_pos = 0;
static uint8_t recv_checksum = 0;
static std::vector<uint8_t> data_buf;

uint8_t calculate_checksum(const uint8_t* data, uint16_t len) {
  uint8_t c = 0;
  for (uint16_t i = 0; i < len; ++i) c ^= data[i];
  return c;
}

static bool received = false;
static std::vector<uint8_t> stored_data;
static bool has_stored = false;
static uint32_t ignore_serial_until = 0;
static bool suppress_serial = false;

// User BOOT button pin (physical BOOT/user button on many dev-boards)
const int USER_BTN_PIN = PA0;
static int last_btn_state = HIGH;

void process_valid_packet() {
  // Turn LED ON briefly to indicate receipt (active LOW on many STM32 dev boards)
  digitalWrite(LED_PIN, LOW);
  // keep LED on for a short acknowledgement period
  // (do not block here; we'll toggle back after storing)
  // store the received payload for later inspection and persist to flash
  // avoid storing duplicate payloads
  if (has_stored && stored_data.size() == data_buf.size()) {
    bool same = true;
    for (size_t i = 0; i < stored_data.size(); ++i) {
      if (stored_data[i] != data_buf[i]) { same = false; break; }
    }
    if (same) {
      // duplicate packet received; ignore re-store but set short ignore window
      ignore_serial_until = HAL_GetTick() + 1000;
      while (Serial.available()) Serial.read();
      if (Serial && !suppress_serial) Serial.println("Duplicate packet received - ignored");
      // reset parser to avoid partial re-entry
      state = WAIT_H1;
      data_buf.clear();
      data_pos = 0;
      return;
    }
  }
  // Always accept valid packets and overwrite stored_data so Apply updates persist
  stored_data = data_buf;
  if (stored_data.size() > 0) {
    bool ok = flash_write_bytes(stored_data.data(), (uint32_t)stored_data.size());
    if (ok) {
      has_stored = true;
      if (Serial && !suppress_serial) Serial.println("hey i am stm32 i got this frame (stored in flash)");
      // guard against immediate re-processing of forwarded bytes
      ignore_serial_until = HAL_GetTick() + 1000;
      // drain any pending incoming bytes to avoid echo re-parsing
      while (Serial.available()) Serial.read();
      state = WAIT_H1;
      data_buf.clear();
      data_pos = 0;
    } else {
      has_stored = false;
      if (Serial && !suppress_serial) Serial.println("Error: failed to write payload to flash");
    }
  }
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH); // LED off (active LOW)

  // configure user button
  pinMode(USER_BTN_PIN, INPUT_PULLUP);
  last_btn_state = digitalRead(USER_BTN_PIN);

  Serial.begin(115200);
  // Initialize HAL (safe to re-init) and USART2 for PA2/PA3
  HAL_Init();
  initUSART2();

  // EEPROM not used on this core; using direct flash-backed storage instead

  // Do NOT clear stored data on NRST: stored data must persist across resets.
  // clear reset flags
  RCC->CSR |= RCC_CSR_RMVF;

  // Load stored data from flash if present
  if (flash_read_bytes(stored_data)) {
    has_stored = true;
    if (Serial && !suppress_serial) Serial.println("Loaded stored payload from flash");
  } else {
    has_stored = false;
  }
}

void loop() {
  while (Serial.available()) {
    // If we're in an ignore window, drain all incoming bytes and skip parsing
    if (ignore_serial_until != 0 && HAL_GetTick() < ignore_serial_until) {
      while (Serial.available()) {
        (void)Serial.read();
      }
      break;
    }
    int v = Serial.read();
    if (v < 0) break;
    uint8_t b = (uint8_t)v;

    switch (state) {
      case WAIT_H1:
        if (b == 0xAE) state = WAIT_H2;
        break;

      case WAIT_H2:
        if (b == 0x53) state = LEN1;
        else state = (b == 0xAE) ? WAIT_H2 : WAIT_H1;
        break;

      case LEN1:
        data_len = ((uint16_t)b) << 8;
        state = LEN2;
        break;

      case LEN2:
        data_len |= b;
        if (data_len == 0 || data_len > 8192) {
          // invalid length — reset silently
          state = WAIT_H1;
        } else {
          data_buf.clear();
          data_buf.reserve(data_len);
          data_pos = 0;
          state = CHK;
        }
        break;

      case CHK:
        recv_checksum = b;
        state = DATA;
        break;

      case DATA:
        data_buf.push_back(b);
        data_pos++;
        if (data_pos >= data_len) state = TERM;
        break;

      case TERM:
        if (b == 0x0A) {
          uint8_t c = calculate_checksum(data_buf.data(), data_len);
          if (c == recv_checksum) {
              process_valid_packet();
            } else {
            // checksum mismatch — ignore
          }
        } else {
          // missing terminator — ignore
        }
        // always reset parser
        state = WAIT_H1;
        break;
    }
  }

  // poll BOOT/user button for a press event (falling edge)
  int btn = digitalRead(USER_BTN_PIN);
  if (btn == LOW && last_btn_state == HIGH) {
    // button pressed (debounced)
    uint32_t start = HAL_GetTick();
    // simple debounce
    delay(50);
    if (digitalRead(USER_BTN_PIN) != LOW) {
      // bounce — ignore
    } else {
      // wait until release to measure duration
      while (digitalRead(USER_BTN_PIN) == LOW) {
        delay(10);
      }
      uint32_t duration = HAL_GetTick() - start;

      if (has_stored) {
        // suppress other serial prints while we output the JSON
        suppress_serial = true;
        // set ignore window BEFORE drain/transmit
        ignore_serial_until = HAL_GetTick() + 5000;
        while (Serial.available()) Serial.read();

        if (duration < 1000) {
          // short press: print JSON atomically to USB only (no USART2)
          if (Serial && !stored_data.empty()) {
            Serial.write(stored_data.data(), stored_data.size());
            Serial.write("\r\n");
          }
        } else {
          // long press: send JSON only over USART2 (no USB print)
          if (!stored_data.empty()) {
            HAL_UART_Transmit(&huart2, (uint8_t*)stored_data.data(), stored_data.size(), 3000);
          }
        }

        // drain any bytes arrived during transmit
        while (Serial.available()) Serial.read();
        suppress_serial = false;
        // reset parser
        state = WAIT_H1;
        data_buf.clear();
        data_pos = 0;
      } else {
        if (Serial && !suppress_serial) Serial.println("<no stored data>");
      }
    }
  }
  last_btn_state = btn;
}
