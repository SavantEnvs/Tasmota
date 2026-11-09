// Berry `json` module: json.load() on the fuzzer input, then json.dump() of whatever it produced.
#include <stddef.h>
#include <stdint.h>
#include "berry.h"

static const char script[] =
    "import json\n"
    "var v = json.load(input)\n"
    "if v != nil\n"
    "  json.dump(v)\n"
    "  json.dump(v, 'format')\n"
    "end\n";

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    bvm *vm = be_vm_new();
    be_pushnstring(vm, (const char *)data, size);
    be_setglobal(vm, "input");
    be_pop(vm, 1);
    if (be_loadbuffer(vm, "json", script, sizeof(script) - 1) == 0) {
        be_pcall(vm, 0);
    }
    be_vm_delete(vm);
    return 0;
}
