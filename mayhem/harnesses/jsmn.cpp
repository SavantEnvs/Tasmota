// jsmn-shadinger (Tasmota's compact JSON tokenizer): tokenize arbitrary text, walk the tokens, unescape strings.
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "jsmn.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    jsmntok_t tokens[64];
    jsmn_parser parser;
    jsmn_init(&parser);
    int n = jsmn_parse(&parser, (const char *)data, size, tokens, 64);
    if (n > 0) {
        char *copy = (char *)malloc(size + 1);
        memcpy(copy, data, size);
        copy[size] = '\0';
        for (int i = 0; i < n; i++) {
            if (tokens[i].type == JSMN_STRING || tokens[i].type == JSMN_KEY) {
                char *s = (char *)malloc(tokens[i].len + 1);
                memcpy(s, copy + tokens[i].start, tokens[i].len);
                s[tokens[i].len] = '\0';
                json_unescape(s);
                free(s);
            }
        }
        free(copy);
    }
    return 0;
}
