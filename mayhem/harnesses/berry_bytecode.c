// Berry precompiled-bytecode (.bec) loader: be_loadfile() on an in-memory "fuzz.bec", never run it.
// be_loadfile() checks the magic itself and falls back to the script compiler, as it does for a real caller.
#include <stddef.h>
#include <stdint.h>
#include "berry.h"

extern const uint8_t *berry_fuzz_file_data;
extern size_t berry_fuzz_file_size;

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    berry_fuzz_file_data = data;
    berry_fuzz_file_size = size;
    bvm *vm = be_vm_new();
    be_loadfile(vm, "fuzz.bec");
    be_vm_delete(vm);
    return 0;
}
