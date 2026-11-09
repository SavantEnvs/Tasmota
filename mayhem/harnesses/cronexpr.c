// ccronexpr: parse a cron expression and walk it forwards and backwards in time.
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "ccronexpr.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    char *expr = malloc(size + 1);
    memcpy(expr, data, size);
    expr[size] = '\0';

    cron_expr parsed;
    memset(&parsed, 0, sizeof(parsed));
    const char *err = NULL;
    cron_parse_expr(expr, &parsed, &err);
    if (err == NULL) {
        time_t t = 1700000000;
        for (int i = 0; i < 4; i++) {
            t = cron_next(&parsed, t);
            if (t == CRON_INVALID_INSTANT) {
                break;
            }
        }
        t = 1700000000;
        for (int i = 0; i < 4; i++) {
            t = cron_prev(&parsed, t);
            if (t == CRON_INVALID_INSTANT) {
                break;
            }
        }
    }
    free(expr);
    return 0;
}
