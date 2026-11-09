// Known-answer checks for the three non-Berry libraries; test.sh compares the printed lines to golden values.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "ccronexpr.h"
#include "jsmn.h"
#include "unishox.h"

static void cron_case(const char *expr, time_t from)
{
    cron_expr e;
    memset(&e, 0, sizeof(e));
    const char *err = NULL;
    cron_parse_expr(expr, &e, &err);
    if (err) {
        printf("cron '%s' error\n", expr);
        return;
    }
    printf("cron '%s' next=%lld prev=%lld\n", expr, (long long)cron_next(&e, from), (long long)cron_prev(&e, from));
}

static void jsmn_case(const char *js)
{
    jsmntok_t tok[32];
    jsmn_parser p;
    jsmn_init(&p);
    int n = jsmn_parse(&p, js, strlen(js), tok, 32);
    printf("jsmn n=%d types=", n);
    for (int i = 0; i < n; i++) {
        printf("%d,%u;", (int)tok[i].type, (unsigned)tok[i].size);
    }
    printf("\n");
}

static void unishox_case(const char *text)
{
    Unishox u;
    char comp[256], back[256];
    int32_t clen = u.unishox_compress(text, strlen(text), comp, sizeof(comp));
    printf("unishox len=%d hex=", (int)clen);
    for (int i = 0; i < clen; i++) {
        printf("%02x", (unsigned char)comp[i]);
    }
    int32_t dlen = u.unishox_decompress(comp, clen, back, sizeof(back));
    back[dlen > 0 ? dlen : 0] = '\0';
    printf(" back=%s\n", back);
}

int main(void)
{
    setenv("TZ", "UTC", 1);
    tzset();
    cron_case("0 0 12 * * *", 1700000000);
    cron_case("*/15 * * * * *", 1700000000);
    cron_case("0 30 8 1 * *", 1700000000);
    cron_case("0 0 0 * * MON-FRI", 1700000000);
    cron_case("bogus", 1700000000);
    cron_case("61 * * * * *", 1700000000);
    jsmn_case("{\"a\":[1,2.5,true,null],\"b\":\"x\\u0041\"}");
    jsmn_case("[1,2");
    jsmn_case("{\"k\":\"v\"}");
    unishox_case("Hello World");
    unishox_case("https://tasmota.github.io/docs/");
    unishox_case("{\"POWER\":\"ON\"}");
    return 0;
}
