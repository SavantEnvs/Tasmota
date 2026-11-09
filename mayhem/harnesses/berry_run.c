// Berry interpreter: compile and RUN the fuzzer input as a script (what `berry file.be` does), console
// output discarded, no filesystem (berry_port.c). Reaches the builtin classes (bytes, list, map, ...).
#include <stddef.h>
#include <stdint.h>
#include "berry.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    bvm *vm = be_vm_new();
    if (be_loadbuffer(vm, "fuzz", (const char *)data, size) == 0) {
        be_pcall(vm, 0);
    }
    be_vm_delete(vm);
    return 0;
}
