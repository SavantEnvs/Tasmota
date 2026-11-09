// Berry lexer + parser + code generator: compile arbitrary script text, never run it.
#include <stddef.h>
#include <stdint.h>
#include "berry.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    bvm *vm = be_vm_new();
    be_loadbuffer(vm, "fuzz", (const char *)data, size);
    be_vm_delete(vm);
    return 0;
}
