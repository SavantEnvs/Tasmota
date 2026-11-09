# Berry: `premark_global()` adds 0 to a NULL pointer

When a bytecode file fails to load before the VM's global table exists, the next GC pass runs
`premark_global()` (`lib/libesp32/berry/src/be_gc.c:448`) with `vlist.data == NULL` and forms
`v + be_global_count(vm)` = `NULL + 0`; UBSan `pointer-overflow` reports "applying zero offset to null pointer".

- Reproduce: build without the `-fno-sanitize=pointer-overflow` relaxation on `be_gc.c` (see `mayhem/build.sh`), then
  `/mayhem/berry_bytecode-standalone mayhem/berry_bytecode/known-findings/gc-null-plus-zero/input`
- Impact: none on the targets Tasmota ships (the loop does not run); it is a UB nit, so that single check is relaxed in the fuzz build.
- Fix: skip the loop when `vlist.data == NULL`.
