# Berry bytecode loader: `load_bytecode` indexes a NULL global-name list

In `load_bytecode()` (`lib/libesp32/berry/src/be_bytecode.c:547`) the loader takes the global-name list from a stack slot
(`var_toobj(be_indexof(vm, info))`); the only check that it is a list is a `be_assert`, which is compiled out. On a
corrupted `.bec` the `OP_GETGBL`/`OP_SETGBL` fix-up then evaluates `be_list_at(list, idx - bcnt)` = `list->data + n`
with `list->data == NULL` and `n != 0`: UBSan `pointer-overflow` ("applying non-zero offset 496 to null pointer"),
and the following read of the name would fault.

- Input: a 1162-byte `.bec` produced by mutating a valid one.
- Reproduce: `/mayhem/berry_bytecode-standalone mayhem/berry_bytecode/known-findings/load-bytecode-null-list/input`
- Impact: a crafted bytecode file makes the loader dereference NULL + offset.
- Fix: validate that the slot holds a list with data (or that `gcnt > 0`) before indexing it, raising `bytecode_error` otherwise.
