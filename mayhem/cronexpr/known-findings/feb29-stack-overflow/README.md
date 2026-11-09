# ccronexpr: unbounded recursion on `0 0 0 29 FEB *`

`cron_next()`/`cron_prev()` on an expression that names a day-of-month the month cannot always
hold (29 FEB) recurse through `do_next`/`do_prev` once per rejected year instead of looping, so a
valid expression exhausts the stack: ASan reports `stack-overflow`.

- Reproduce: `/mayhem/cronexpr-standalone mayhem/cronexpr/known-findings/feb29-stack-overflow/input`
- Impact: the cron expression comes from a Berry/Tasmota Timer or rule setting; a device crashes
  (watchdog reboot) when the next trigger time is computed.
- Fix: iterate to the next candidate year in a loop, with the existing year-limit bound, rather than recursing.
