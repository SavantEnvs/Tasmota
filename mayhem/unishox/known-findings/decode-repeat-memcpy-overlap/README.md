# Unishox: `decodeRepeat()` copies overlapping ranges with `memcpy`

`unishox.cpp:448` expands a back-reference with `memcpy(out + ol, out + ol - dist, count)`. A crafted
compressed stream can make `dist < count`, so source and destination overlap: ASan reports
`memcpy-param-overlap`, and the expanded text is whatever the libc copy order produces.

- Reproduce: `/mayhem/unishox-standalone mayhem/unishox/known-findings/decode-repeat-memcpy-overlap/input`
  (first byte 1 selects the decompress path).
- Impact: undefined behaviour in `Unishox::unishox_decompress()` on attacker-supplied compressed text
  (Berry `unishox` module, compressed Tasmota rule/UI strings).
- Fix: replace the `memcpy` with a forward byte loop (or `memmove`) so overlapping back-references repeat correctly.
