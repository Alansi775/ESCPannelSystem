#include <Arduino.h>
#include <vector>
#include "stm32f4xx.h"
#include "stm32f4xx_hal.h"

UART_HandleTypeDef huart4;

// Buffer and state for receiving frames over UART4
static std::vector<uint8_t> frame_buf;
static bool in_frame = false;
static std::vector<uint8_t> stored_data;
static bool has_stored = false;
volatile static uint32_t rx_count = 0;

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
        // Received a complete frame
        stored_data = frame_buf;
        has_stored = true;
        
        HAL_UART_Transmit(&huart4, (uint8_t*)"\r\n=== FRAME RECEIVED ===\r\n", 25, 100);
        HAL_UART_Transmit(&huart4, (uint8_t*)"HEX: ", 5, 50);
        print_hex(stored_data.data(), stored_data.size());
        HAL_UART_Transmit(&huart4, (uint8_t*)"======================\r\n\r\n", 26, 100);
        
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
}

void loop() {
  static uint32_t last_alive = 0;
  static uint32_t last_print = 0;
  uint32_t now = HAL_GetTick();
  
  // Alive message every 5 seconds
  if ((now - last_alive) >= 5000) {
    last_alive = now;
    char msg[50];
    snprintf(msg, sizeof(msg), "Alive... RX count: %lu\r\n", (unsigned long)rx_count);
    HAL_UART_Transmit(&huart4, (uint8_t*)msg, strlen(msg), 100);
  }
  
  // Receiving data over UART4
  uint8_t rb;
  while (HAL_UART_Receive(&huart4, &rb, 1, 2) == HAL_OK) {
    handle_received_byte(rb);
  }
  
  // Print stored data every second
  if (has_stored && (now - last_print) >= 1000) {
    last_print = now;
    HAL_UART_Transmit(&huart4, (uint8_t*)"Stored: ", 8, 50);
    print_hex(stored_data.data(), stored_data.size());
  }
  
  delay(2);
}