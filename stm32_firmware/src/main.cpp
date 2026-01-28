#include <Arduino.h>
#include <string>
#include <vector>
#include "stm32f4xx.h"

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

// User BOOT button pin (physical BOOT/user button on many dev-boards)
const int USER_BTN_PIN = PA0;
static int last_btn_state = HIGH;

void process_valid_packet() {
  if (received) return; // already handled
  // Turn LED ON (active LOW on many STM32 dev boards)
  digitalWrite(LED_PIN, LOW);
  received = true;
  // store the received payload for later inspection
  stored_data = data_buf;
  has_stored = true;

  // Print an acknowledgement immediately as well
  if (Serial) {
    Serial.println("hey i am stm32 i got this frame (stored)");
  }
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH); // LED off (active LOW)

  // configure user button
  pinMode(USER_BTN_PIN, INPUT_PULLUP);
  last_btn_state = digitalRead(USER_BTN_PIN);

  Serial.begin(115200);

  // If the last reset was caused by an external pin reset (NRST), clear stored data
  uint32_t csr = RCC->CSR;
  if (csr & RCC_CSR_PINRSTF) {
    // external reset detected -> clear stored data
    stored_data.clear();
    has_stored = false;
    if (Serial) Serial.println("NRST detected on boot - cleared stored data");
  }
  // clear reset flags
  RCC->CSR |= RCC_CSR_RMVF;
}

void loop() {
  while (Serial.available()) {
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
    // button pressed
    if (Serial) {
      Serial.println("hey i am connected now");
      if (has_stored) {
        std::string s(stored_data.begin(), stored_data.end());
        Serial.println(s.c_str());
      } else {
        Serial.println("<no stored data>");
      }
    }
  }
  last_btn_state = btn;
}
