// Unishox (short-string compressor): first input byte picks decompress-untrusted-bytes or compress+decompress round trip.
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "unishox.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    if (size < 1) {
        return -1;
    }
    const char *in = (const char *)data + 1;
    size_t len = size - 1;
    Unishox u;
    if (data[0] & 1) {
        char out[2048];
        u.unishox_decompress(in, len, out, sizeof(out));
    } else {
        size_t cap = len * 2 + 16;
        char *comp = (char *)malloc(cap);
        int32_t clen = u.unishox_compress(in, len, comp, cap);
        if (clen > 0) {
            char *back = (char *)malloc(len + 1);
            int32_t dlen = u.unishox_decompress(comp, clen, back, len + 1);
            if (dlen != (int32_t)len || memcmp(back, in, len) != 0) {
                abort();
            }
            free(back);
        }
        free(comp);
    }
    return 0;
}
