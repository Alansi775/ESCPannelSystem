#pragma once
#include <stddef.h>
#include <stdint.h>

// Access stored frame (copied). Returns number of bytes written to buf (0 if none).
size_t frame_store_get(uint8_t* buf, size_t maxlen);

// Return whether a stored frame exists
int frame_store_has(void);
