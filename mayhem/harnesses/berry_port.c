// Host-environment port for the Berry fuzz build (replaces lib/libesp32/berry/default/be_port.c).
// Console output is discarded, stdin is empty, and the only file that exists is the in-memory
// "fuzz.bec" holding the fuzzer input, so the interpreter never touches the real filesystem.
#include <stdint.h>
#include <string.h>
#include "berry.h"
#include "be_sys.h"

const uint8_t *berry_fuzz_file_data;
size_t berry_fuzz_file_size;

typedef struct { size_t pos; } memfile_t;
static memfile_t g_memfile;

BERRY_API void be_writebuffer(const char *buffer, size_t length)
{
    (void)buffer; (void)length;
}

BERRY_API char* be_readstring(char *buffer, size_t size)
{
    (void)buffer; (void)size;
    return NULL;
}

void* be_fopen(const char *filename, const char *modes)
{
    if (modes[0] != 'r' || strcmp(filename, "fuzz.bec") != 0) {
        return NULL;
    }
    g_memfile.pos = 0;
    return &g_memfile;
}

int be_fclose(void *hfile) { (void)hfile; return 0; }

size_t be_fwrite(void *hfile, const void *buffer, size_t length)
{
    (void)hfile; (void)buffer; (void)length;
    return 0;
}

size_t be_fread(void *hfile, void *buffer, size_t length)
{
    memfile_t *f = hfile;
    size_t left = berry_fuzz_file_size - f->pos;
    if (length > left) {
        length = left;
    }
    if (length) {
        memcpy(buffer, berry_fuzz_file_data + f->pos, length);
    }
    f->pos += length;
    return length;
}

char* be_fgets(void *hfile, void *buffer, int size)
{
    memfile_t *f = hfile;
    char *out = buffer;
    int n = 0;
    while (n < size - 1 && f->pos < berry_fuzz_file_size) {
        char c = (char)berry_fuzz_file_data[f->pos++];
        out[n++] = c;
        if (c == '\n') {
            break;
        }
    }
    if (n == 0) {
        return NULL;
    }
    out[n] = '\0';
    return buffer;
}

int be_fseek(void *hfile, long offset)
{
    memfile_t *f = hfile;
    if (offset < 0 || (size_t)offset > berry_fuzz_file_size) {
        return -1;
    }
    f->pos = (size_t)offset;
    return 0;
}

long int be_ftell(void *hfile) { return (long)((memfile_t *)hfile)->pos; }
long int be_fflush(void *hfile) { (void)hfile; return 0; }
size_t be_fsize(void *hfile) { (void)hfile; return berry_fuzz_file_size; }

int be_isdir(const char *path) { (void)path; return 0; }
int be_isfile(const char *path) { return strcmp(path, "fuzz.bec") == 0; }
int be_isexist(const char *path) { return be_isfile(path); }
char* be_getcwd(char *buf, size_t size)
{
    if (size < 2) {
        return NULL;
    }
    buf[0] = '/';
    buf[1] = '\0';
    return buf;
}
int be_chdir(const char *path) { (void)path; return -1; }
int be_mkdir(const char *path) { (void)path; return -1; }
int be_unlink(const char *filename) { (void)filename; return -1; }
int be_dirfirst(bdirinfo *info, const char *path) { (void)info; (void)path; return -1; }
int be_dirnext(bdirinfo *info) { (void)info; return -1; }
int be_dirclose(bdirinfo *info) { (void)info; return 0; }
