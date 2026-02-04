// ITM / SWO trace and newlib retarget for printing via SWO (ST-Link)
#include "stm32f4xx.h"
#include <stdint.h>
#include <sys/types.h>

// Initialize SWO / ITM for printf output over the ST-Link
extern "C" void trace_init(uint32_t cpu_hz, uint32_t swo_hz) {
  // Enable TRC
  CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk;

  // Unlock ITM (if present)
#ifdef ITM
  ITM->LAR = 0xC5ACCE55UL;
#endif

  // Configure TPIU prescaler for desired SWO baud: SWO_freq = cpu_hz / (ACPR+1)
  if (swo_hz == 0) return;
  uint32_t prescaler = (cpu_hz / swo_hz);
  if (prescaler) prescaler -= 1;
  TPI->ACPR = prescaler;
  // Use NRZ / asynchronous mode
  TPI->SPPR = 0x2;
  // Formatter: disable continuous formatting
  TPI->FFCR = 0x00000100;

  // Enable ITM
  ITM->TCR = ITM_TCR_ITMENA_Msk | ITM_TCR_SYNCENA_Msk | ITM_TCR_TSENA_Msk;
  // Enable stimulus port 0
  ITM->TER = 0x1;
}

// Send a single character to ITM port 0 (blocking)
static inline int ITM_SendChar(int ch) {
  if ((CoreDebug->DEMCR & CoreDebug_DEMCR_TRCENA_Msk) == 0) return ch;
  if ((ITM->TCR & ITM_TCR_ITMENA_Msk) == 0) return ch;
  if ((ITM->TER & 1) == 0) return ch;
  // Wait until ready
  while (ITM->PORT[0].u32 == 0);
  ITM->PORT[0].u8 = (uint8_t)ch;
  return ch;
}

extern "C" {
// newlib syscall override for write (simple implementation)
int _write(int file, const char *ptr, int len) {
  (void)file;
  for (int i = 0; i < len; ++i) {
    ITM_SendChar(ptr[i]);
  }
  return len;
}

// newlib reentrant variant
int _write_r(void *reent, int fd, const void *buf, size_t cnt) {
  (void)reent; (void)fd;
  const uint8_t *p = (const uint8_t*)buf;
  for (size_t i = 0; i < cnt; ++i) ITM_SendChar(p[i]);
  return (int)cnt;
}
}
