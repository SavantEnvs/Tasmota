# Berry code generator: `be_eqstr` reads a freed string while folding constants

While compiling a script, `findconst()` (`lib/libesp32/berry/src/be_code.c:311`) compares a new string constant with the
constants already in the function prototype using `be_eqstr()` (`be_string.c:59`/`:61`). On this input one of the
strings it touches has already been freed by a GC pass triggered during parsing, so ASan reports `heap-use-after-free`
(the read is in `be_eqstr`, the string is the constant held by the expression or the constant table).

- Input: a 658-byte script found by the fuzzer.
- Reproduce: `/mayhem/berry_script-standalone mayhem/berry_script/known-findings/findconst-use-after-free/input`
- Impact: memory-safety bug in the compiler (reads freed heap memory) reachable from any script text.
- Fix: keep the string referenced (on the VM stack or in the prototype's constant table) from the moment the lexer creates it until `findconst()`/`be_code` has used it.
