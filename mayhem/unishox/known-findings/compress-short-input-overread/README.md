# Unishox: `unishox_compress` reads past the input for lengths below 4

`unishox_compress()` (`lib/default/Unishox-Tasmota-1.0/src/unishox.cpp:269`) tests `l < len - 4` for its repeat
detection. `len` is unsigned, so for `len < 4` the subtraction wraps to a huge value, the test is true, and
`in[l + 1]`, `in[l + 2]`, `in[l + 3]` read past the end of the input: ASan `heap-buffer-overflow`.

- Input: 3 spaces; the harness uses the first byte as a mode byte (even = round trip) and compresses the remaining 2 bytes.
- Reproduce: `/mayhem/unishox-standalone mayhem/unishox/known-findings/compress-short-input-overread/input`
- Impact: compressing a short string (here two equal bytes) over-reads the caller's buffer by up to 3 bytes.
- Fix: write the condition as `l + 4 < len` (or `len > 4 && l < len - 4`).
