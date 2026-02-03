#ifndef PROTOCOL_H
#define PROTOCOL_H
#include <stddef.h>
#include <stdint.h>
#include "app_config.h"

size_t pack_appconfig_frame(const AppConfig& cfg, uint8_t* buf, size_t bufsize);
void build_and_print_frame_v2(const AppConfig& cfg);
bool send_frame_can(const uint8_t* data, size_t len);
bool send_frame_i2c(const uint8_t* data, size_t len, uint8_t addr);

#endif // PROTOCOL_H
