# Berry lexer: a string literal ending in a backslash reads past the EOS sentinel

`scan_one_literal()` (`lib/libesp32/berry/src/be_lexer.c:788`) saves the character after a `\` unconditionally. When the
script ends right after the backslash, that character is the `EOS` sentinel (a one-byte static), so the cursor moves past
it and the next `next()` (`be_lexer.c:111`) reads beyond the sentinel: ASan `global-buffer-overflow`.

- Input: the 9 bytes `"\02oust\` (an unterminated string whose last byte is a backslash).
- Reproduce: `/mayhem/berry_script-standalone mayhem/berry_script/known-findings/lexer-read-past-eos/input`
- Impact: any Berry script (a Tasmota rule/script loaded from the filesystem or typed into the console) can make the compiler read one or more bytes past a static.
- Fix: stop at `EOS` after a backslash (do not `save()`/advance when the escaped character is `EOS`).
