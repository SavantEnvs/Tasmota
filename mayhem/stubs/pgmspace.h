// Host stand-in for the ESP8266/ESP32 <pgmspace.h> used by Unishox: flash and RAM share one address space here.
// pgm_read_word() on a byte table reads only that byte: Unishox masks the result back to 8 bits, and a
// literal 16-bit load would run one byte past the end of `mask[]`.
#pragma once
#include <stdint.h>
#define PROGMEM
template <typename T> static inline uint16_t mayhem_pgm_read_word(const T *p)
{
    return sizeof(T) == 1 ? (uint16_t)*(const uint8_t *)p : (uint16_t)*(const uint16_t *)p;
}
#define pgm_read_byte(addr) (*(const uint8_t *)(addr))
#define pgm_read_word(addr) mayhem_pgm_read_word(addr)
