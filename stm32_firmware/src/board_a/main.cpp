#include <Arduino.h>
#include <string>
#include <vector>
//#include <EEPROM.h> // replaced by direct flash storage
#include "stm32f4xx.h"
#include "stm32f4xx_hal.h"
#include <cstring>
#include "app_config.h"
#include "json_parser.h"
#include "protocol.h"

// ITM trace init (SWO)
extern "C" void trace_init(uint32_t cpu_hz, uint32_t swo_hz);

// AppConfig and enums moved to app_config.h

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

// Keep legacy LED pin and add support for common F4 discovery/nucleo LEDs
#define LED_PIN PC13
#define LED_ALT_PORT GPIOD
#define LED_ALT_PIN GPIO_PIN_12

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
// When true, stop printing via USB-Serial; logs will go over ITM/SWO
static bool suppress_serial = false;
static volatile uint32_t led_on_until = 0;
static uint32_t last_heartbeat = 0;
static bool heartbeat_enabled = false; // keep disabled now
static bool in_raw_json = false;
static std::vector<uint8_t> raw_json_buf;

// parsed configuration ready for framing/transports
static AppConfig current_config;
static bool config_ready = false;

// Read a single byte non-blocking from available interfaces.
// Returns -1 if no byte available, otherwise 0..255 value.
static int read_byte_nonblocking() {
  // Prefer hardware USART2 (TTL adapter) if available
  if (huart2.Instance != NULL) {
    if ((__HAL_UART_GET_FLAG(&huart2, UART_FLAG_RXNE)) != RESET) {
      uint8_t ch = (uint8_t)(huart2.Instance->DR & 0xFF);
      return (int)ch;
    }
  }
  // Fallback to USB-CDC Serial
  if (Serial && Serial.available()) {
    int v = Serial.read();
    return v;
  }
  return -1;
}

// Drain any pending input bytes from all sources
static void drain_input() {
  while (read_byte_nonblocking() >= 0) {
    ;
  }
}

// User BOOT button pin (physical BOOT/user button on many dev-boards)
const int USER_BTN_PIN = PA0;
static int last_btn_state = HIGH;

// Debug helper: print current_config over USB Serial
static void debug_print_config() {
  if (!Serial) return;
  Serial.println("---- AppConfig ----");
  Serial.print("version: "); Serial.println((int)current_config.version);
  Serial.print("battery_cells: "); Serial.println((int)current_config.battery_cells);
  Serial.print("battery_voltage: "); Serial.println(current_config.battery_voltage);
  Serial.print("battery_nominal: "); Serial.println(current_config.battery_nominal);
  Serial.print("sensor_type: "); Serial.println((int)current_config.sensor_type);
  Serial.print("sensor_max_rpm: "); Serial.println((unsigned long)current_config.sensor_max_rpm);
  Serial.print("motor_kv: "); Serial.println((int)current_config.motor_kv);
  Serial.print("motor_poles: "); Serial.println((int)current_config.motor_poles);
  Serial.print("control_mode: "); Serial.println((int)current_config.control_mode);
  Serial.print("control_current_limit: "); Serial.println((int)current_config.control_current_limit);
  Serial.print("control_pwm_frequency: "); Serial.println((int)current_config.control_pwm_frequency);
  Serial.print("control_brake_enabled: "); Serial.println((int)current_config.control_brake_enabled);
  Serial.print("safety_max_tempreature: "); Serial.println((int)current_config.safety_max_tempreature);
  Serial.print("safety_overcurrent_limit: "); Serial.println((int)current_config.safety_overcurrent_limit);
  Serial.print("reserved: ");
  for (int i = 0; i < 3; ++i) { Serial.print((int)current_config.reserved[i]); Serial.print(i<2?",":"\n"); }
  Serial.println("-------------------");
}

// send a NUL-terminated string over USART2 if available
static void usart2_print(const char* s) {
  if (huart2.Instance != NULL) {
    HAL_UART_Transmit(&huart2, (uint8_t*)s, (uint16_t)strlen(s), 200);
  }
}

// Print AppConfig over USART2 (same content as debug_print_config)
static void debug_print_config_uart() {
  if (huart2.Instance == NULL) return;
  char buf[128];
  usart2_print("---- AppConfig ----\r\n");
  snprintf(buf, sizeof(buf), "version: %d\r\n", (int)current_config.version); usart2_print(buf);
  snprintf(buf, sizeof(buf), "battery_cells: %d\r\n", (int)current_config.battery_cells); usart2_print(buf);
  snprintf(buf, sizeof(buf), "battery_voltage: %.2f\r\n", current_config.battery_voltage); usart2_print(buf);
  snprintf(buf, sizeof(buf), "battery_nominal: %.2f\r\n", current_config.battery_nominal); usart2_print(buf);
  snprintf(buf, sizeof(buf), "sensor_type: %d\r\n", (int)current_config.sensor_type); usart2_print(buf);
  snprintf(buf, sizeof(buf), "sensor_max_rpm: %lu\r\n", (unsigned long)current_config.sensor_max_rpm); usart2_print(buf);
  snprintf(buf, sizeof(buf), "motor_kv: %d\r\n", (int)current_config.motor_kv); usart2_print(buf);
  snprintf(buf, sizeof(buf), "motor_poles: %d\r\n", (int)current_config.motor_poles); usart2_print(buf);
  snprintf(buf, sizeof(buf), "control_mode: %d\r\n", (int)current_config.control_mode); usart2_print(buf);
  snprintf(buf, sizeof(buf), "control_current_limit: %d\r\n", (int)current_config.control_current_limit); usart2_print(buf);
  snprintf(buf, sizeof(buf), "control_pwm_frequency: %d\r\n", (int)current_config.control_pwm_frequency); usart2_print(buf);
  snprintf(buf, sizeof(buf), "control_brake_enabled: %d\r\n", (int)current_config.control_brake_enabled); usart2_print(buf);
  snprintf(buf, sizeof(buf), "safety_max_tempreature: %d\r\n", (int)current_config.safety_max_tempreature); usart2_print(buf);
  snprintf(buf, sizeof(buf), "safety_overcurrent_limit: %d\r\n", (int)current_config.safety_overcurrent_limit); usart2_print(buf);
  snprintf(buf, sizeof(buf), "reserved: %d,%d,%d\r\n", (int)current_config.reserved[0], (int)current_config.reserved[1], (int)current_config.reserved[2]); usart2_print(buf);
  usart2_print("-------------------\r\n");
}

// print hex over usart2
static void print_hex_uart(const uint8_t* buf, size_t len) {
  if (huart2.Instance == NULL) return;
  char s[8];
  for (size_t i = 0; i < len; ++i) {
    snprintf(s, sizeof(s), "%02X", buf[i]);
    usart2_print(s);
    if (i + 1 < len) usart2_print(" ");
  }
  usart2_print("\r\n");
}

// forward-declare print_hex (defined later) so earlier helpers can call it
static void print_hex(const uint8_t* buf, size_t len);

// Common handler: store payload bytes to flash, parse to AppConfig, build frame,
// broadcast and print on Serial/USART2. Returns true if successfully stored and parsed.
static bool store_and_apply_payload(const std::vector<uint8_t>& payload) {
  if (payload.empty()) return false;
  if (!flash_write_bytes(payload.data(), (uint32_t)payload.size())) {
    if (Serial && !suppress_serial) Serial.println("Error: failed to write payload to flash");
    if (huart2.Instance != NULL) usart2_print("Error: failed to write payload to flash\r\n");
    return false;
  }
  stored_data = payload;
  has_stored = true;
  config_ready = false;
  if (jsonparser::parse_json_to_appconfig(stored_data, current_config)) {
    config_ready = true;
    if (Serial && !suppress_serial) Serial.println("Stored and parsed config -> ready");
    debug_print_config();
    debug_print_config_uart();
    // build and broadcast deterministic frame
    uint8_t frame_buf[64];
    size_t flen = pack_appconfig_frame(current_config, frame_buf, sizeof(frame_buf));
    if (flen > 0) {
      // Do not transmit raw binary on USART2; print ASCII hex instead for TTL monitor.
      if (Serial && !suppress_serial) {
        Serial.print("Broadcasted frame (bytes): "); Serial.println((int)flen);
        Serial.print("Frame hex: "); print_hex(frame_buf, flen);
      }
      print_hex_uart(frame_buf, flen);
      // also V2 frame for ESC
      build_and_print_frame_v2(current_config);
      // attempt CAN/I2C
      send_frame_can(frame_buf, flen);
      send_frame_i2c(frame_buf, flen, 0x42);
    }
    return true;
  } else {
    if (Serial && !suppress_serial) Serial.println("Stored but failed to parse JSON");
    if (huart2.Instance != NULL) usart2_print("Stored but failed to parse JSON\r\n");
    return false;
  }
}

// Utility: print hex dump of buffer to USB Serial
static void print_hex(const uint8_t* buf, size_t len) {
  if (!Serial) return;
  for (size_t i = 0; i < len; ++i) {
    uint8_t v = buf[i];
    char s[4];
    const char hex[] = "0123456789ABCDEF";
    s[0] = hex[(v >> 4) & 0xF];
    s[1] = hex[v & 0xF];
    s[2] = '\0';
    Serial.print(s);
    if (i + 1 < len) Serial.print(' ');
  }
  Serial.println();
}

void set_led(bool on) {
  // Support boards with PC13 (active LOW) and PD12 (active HIGH)
  // PC13: LED on = LOW; PD12: LED on = HIGH
  // Attempt both so the appropriate LED lights on either board.
  HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, on ? GPIO_PIN_RESET : GPIO_PIN_SET);
  HAL_GPIO_WritePin(LED_ALT_PORT, LED_ALT_PIN, on ? GPIO_PIN_SET : GPIO_PIN_RESET);
}

void process_valid_packet() {
  // Turn LED ON briefly to indicate receipt
  set_led(true);
  led_on_until = HAL_GetTick() + 200; // 200 ms indicator
  // (do not block here; LED will be reset in main loop)
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
      drain_input();
      if (Serial && !suppress_serial) Serial.println("Duplicate packet received - ignored");
      // reset parser to avoid partial re-entry
      state = WAIT_H1;
      data_buf.clear();
      data_pos = 0;
      return;
    }
  }
  // Always accept valid framed packets and process their payload
  if (!data_buf.empty()) {
    store_and_apply_payload(data_buf);
    // guard against immediate re-processing of forwarded bytes
    ignore_serial_until = HAL_GetTick() + 1000;
    drain_input();
  }
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  // ensure clocks and pins for common LED locations are configured
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOD_CLK_ENABLE();
  digitalWrite(LED_PIN, HIGH); // LED off (active LOW)

  // configure user button
  pinMode(USER_BTN_PIN, INPUT_PULLUP);
  last_btn_state = digitalRead(USER_BTN_PIN);

  Serial.begin(115200);
  // Initialize HAL (safe to re-init) and USART2 for PA2/PA3
  HAL_Init();
  // Initialize SWO/ITM tracing (2 MHz). Keep USB serial enabled so we can
  // read incoming data over the TTL adapter / USB-Serial device.
  trace_init(SystemCoreClock, 2000000);
  suppress_serial = false;

  // If the reset was caused by an external pin reset (NRST), clear stored data
  // Capture reset flags so we can react after loading stored data.
  uint32_t reset_flags = RCC->CSR;
  initUSART2();

  // notify over USART2 that TTL serial is ready
  if (huart2.Instance != NULL) {
    const char ready[] = "UART2 ready\r\n";
    HAL_UART_Transmit(&huart2, (uint8_t*)ready, (uint16_t)strlen(ready), 100);
  }

  // EEPROM not used on this core; using direct flash-backed storage instead

  // Do NOT clear stored data on NRST: stored data must persist across resets.
  // clear reset flags
  RCC->CSR |= RCC_CSR_RMVF;

  // Load stored data from flash if present
  if (flash_read_bytes(stored_data)) {
    has_stored = true;
    if (Serial && !suppress_serial) Serial.println("Loaded stored payload from flash");
    // parse existing stored JSON into AppConfig so EEPROM/flash data is applied on boot
    config_ready = false;
    if (jsonparser::parse_json_to_appconfig(stored_data, current_config)) {
      config_ready = true;
      if (Serial && !suppress_serial) {
        Serial.println("Parsed stored config on startup");
        debug_print_config();
      }
      // broadcast current config frame on startup over USART2
      uint8_t frame_buf[64];
      size_t flen = pack_appconfig_frame(current_config, frame_buf, sizeof(frame_buf));
      if (flen > 0) {
        print_hex_uart(frame_buf, flen);
        if (Serial && !suppress_serial) {
          Serial.print("Startup frame hex: ");
          print_hex(frame_buf, flen);
            // also print V2 frame
            build_and_print_frame_v2(current_config);
        }
        bool can_ok = send_frame_can(frame_buf, flen);
        bool i2c_ok = send_frame_i2c(frame_buf, flen, 0x42);
        if (Serial && !suppress_serial) {
          Serial.print("CAN send: "); Serial.println(can_ok?"ok":"no");
          Serial.print("I2C send: "); Serial.println(i2c_ok?"ok":"no");
        }
      }
    } else {
      if (Serial && !suppress_serial) Serial.println("Failed to parse stored JSON on startup");
    }
  } else {
    has_stored = false;
  }

  // If the reset was caused by an external pin reset (NRST/PINRSTF),
  // broadcast the stored JSON/config/frame instead of erasing it.
  if (reset_flags & RCC_CSR_PINRSTF) {
    if (has_stored) {
      if (Serial && !suppress_serial) Serial.println("NRST detected: broadcasting stored payload");
      if (Serial) {
        Serial.write(stored_data.data(), stored_data.size());
        Serial.write("\r\n");
      }
      if (huart2.Instance != NULL) {
        HAL_UART_Transmit(&huart2, (uint8_t*)stored_data.data(), stored_data.size(), 3000);
        HAL_UART_Transmit(&huart2, (uint8_t*)"\r\n", 2, 50);
      }
      // ensure parsed and printed
      if (!config_ready) {
        if (jsonparser::parse_json_to_appconfig(stored_data, current_config)) config_ready = true;
      }
      if (config_ready) {
        debug_print_config();
        debug_print_config_uart();
        // build and broadcast deterministic frame
        uint8_t frame_buf[64];
        size_t flen = pack_appconfig_frame(current_config, frame_buf, sizeof(frame_buf));
        if (flen > 0) {
          // Do not transmit raw binary on USART2; print ASCII hex instead and send binary on CAN/I2C.
          if (Serial && !suppress_serial) {
            Serial.print("NRST Broadcast Frame hex: "); print_hex(frame_buf, flen);
          }
          print_hex_uart(frame_buf, flen);
        }
      }
    } else {
      if (Serial && !suppress_serial) Serial.println("NRST detected: no stored payload");
      if (huart2.Instance != NULL) usart2_print("NRST detected: no stored payload\r\n");
    }
  }
}

void loop() {
  // handle LED timeout (turn off after short indicator)
  if (led_on_until != 0 && HAL_GetTick() >= led_on_until) {
    set_led(false);
    led_on_until = 0;
  }

  // heartbeat for TTL / serial debug: print a simple line every 1s
  if (heartbeat_enabled && (HAL_GetTick() - last_heartbeat) >= 1000) {
    last_heartbeat = HAL_GetTick();
    const char hb[] = "hello world\r\n";
    if (!suppress_serial && huart2.Instance != NULL) {
      HAL_UART_Transmit(&huart2, (uint8_t*)hb, (uint16_t)strlen(hb), 50);
    } else if (Serial && !suppress_serial) {
      Serial.println("hello world");
    }
  }
  // Read bytes from USART2 or Serial (non-blocking) and feed to parser
  while (true) {
    // If we're in an ignore window, drain all incoming bytes and skip parsing
    if (ignore_serial_until != 0 && HAL_GetTick() < ignore_serial_until) {
      drain_input();
      break;
    }
    int v = read_byte_nonblocking();
    if (v < 0) break;
    uint8_t b = (uint8_t)v;

    // (no diagnostic echo) -- do not mirror raw bytes to avoid mixing binary

    // Raw JSON mode: detect start of JSON object/array and collect until newline
    if (!in_raw_json && (b == '{' || b == '[')) {
      in_raw_json = true;
      raw_json_buf.clear();
      raw_json_buf.push_back(b);
      continue; // read next byte
    }
    if (in_raw_json) {
      raw_json_buf.push_back(b);
      if (b == '\n') {
        // process raw JSON line (trim trailing CR/LF)
        while (!raw_json_buf.empty() && (raw_json_buf.back() == '\n' || raw_json_buf.back() == '\r')) raw_json_buf.pop_back();
        if (!raw_json_buf.empty()) {
          store_and_apply_payload(raw_json_buf);
        }
        in_raw_json = false;
        raw_json_buf.clear();
      }
      continue; // handled as raw JSON
    }

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
        drain_input();

        if (duration < 1000) {
          // short press: print JSON atomically to USB only (no USART2)
          if (!stored_data.empty()) {
            if (Serial) {
              Serial.write(stored_data.data(), stored_data.size());
              Serial.write("\r\n");
            }
            if (huart2.Instance != NULL) {
              HAL_UART_Transmit(&huart2, (uint8_t*)stored_data.data(), stored_data.size(), 3000);
              HAL_UART_Transmit(&huart2, (uint8_t*)"\r\n", 2, 50);
            }
            // Also attempt to parse and print parsed AppConfig for verification
            if (!config_ready) {
              if (jsonparser::parse_json_to_appconfig(stored_data, current_config)) {
                config_ready = true;
              }
            }
            if (config_ready) {
              debug_print_config();
              debug_print_config_uart();
              // V2 frame hex
              build_and_print_frame_v2(current_config);
              // also print ASCII frame hex on huart2
              uint8_t frame_buf2[64];
              size_t flen2 = pack_appconfig_frame(current_config, frame_buf2, sizeof(frame_buf2));
              if (flen2 > 0) print_hex_uart(frame_buf2, flen2);
            }
          }
        } else {
          // long press: send JSON only over USART2 (no USB print)
          if (!stored_data.empty()) {
            HAL_UART_Transmit(&huart2, (uint8_t*)stored_data.data(), stored_data.size(), 3000);
            // Also pack deterministic frame and send after raw JSON
            if (!config_ready) {
              if (jsonparser::parse_json_to_appconfig(stored_data, current_config)) {
                config_ready = true;
              }
            }
            if (config_ready) {
              uint8_t frame_buf[64];
              size_t flen = pack_appconfig_frame(current_config, frame_buf, sizeof(frame_buf));
              if (flen > 0) {
                // Do not send raw binary on USART2; print hex instead.
                if (Serial && !suppress_serial) {
                  Serial.print("Frame hex: ");
                  print_hex(frame_buf, flen);
                }
                print_hex_uart(frame_buf, flen);
                bool can_ok = send_frame_can(frame_buf, flen);
                bool i2c_ok = send_frame_i2c(frame_buf, flen, 0x42);
                if (Serial && !suppress_serial) {
                  Serial.print("CAN send: "); Serial.println(can_ok?"ok":"no");
                  Serial.print("I2C send: "); Serial.println(i2c_ok?"ok":"no");
                }
                // also print V2 frame for ESC
                build_and_print_frame_v2(current_config);
              }
            }
          }
        }

        // drain any bytes arrived during transmit
        drain_input();
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