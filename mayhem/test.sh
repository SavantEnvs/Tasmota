#!/usr/bin/env bash
#
# mayhem/test.sh — RUN this repo's OWN functional test suite (already built by mayhem/build.sh).
# exit 0 = pass. EDIT per repo. PATCH-grade oracle: after an agent patches the source, the grader
# rebuilds (build.sh) then runs this. DELETE this file if the repo has no meaningful tests.
#
# IMPORTANT:
#  * Must assert BEHAVIOR/OUTPUT, not just exit status. The oracle has to check asserted values /
#    golden-output diffs / known-answer results — so a PATCH that "fixes" a bug by making the program
#    exit(0) (or any no-op) FAILS here. Running inputs and checking only "exit 0 / didn't crash" is
#    NOT a functional test (it's trivially reward-hackable) — use the project's real assertion suite.
#  * Do NOT build here — mayhem/build.sh already compiled the test suite (with the project's normal
#    flags). This script only RUNS the pre-built tests and reports counts. If the test runner is
#    missing, that's a build.sh bug — fail loudly rather than silently rebuilding.
#  * REQUIRED OUTPUT — a CTRF (https://ctrf.io) summary so Mayhem/the PATCH grader reads the counts:
#      - writes a CTRF JSON report to ${CTRF_REPORT:-$SRC/ctrf-report.json}, and
#      - prints a one-line `CTRF {...}` marker to stdout (same JSON, compact).
#    Only `results.summary` (with tests/passed/failed/pending/skipped/other) is required.
#    Use the emit_ctrf helper below; it computes tests = passed+failed+skipped and sets the exit
#    code (0 iff failed==0). Map your framework's output to passed/failed/skipped.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# Oracle: upstream's Berry test-suite (lib/libesp32/berry/tests/*.be, run by the `berry` that build.sh
# built with upstream's own Makefile)
# Every check is judged on the interpreter's actual OUTPUT (a sentinel the test prints only
# after its last assertion, golden lines), never on an exit status alone.
BERRY_DIR="$SRC/lib/libesp32/berry"
BERRY_BIN="$BERRY_DIR/berry"
for f in "$BERRY_BIN"; do
  [ -x "$f" ] || { echo "missing $f — mayhem/build.sh must build it" >&2; emit_ctrf "tasmota" 0 1 0; exit 1; }
done

passed=0 ; failed=0 ; skipped=0
pass() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $*" >&2; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
SENTINEL='__BERRY_TEST_PASSED__'

# --- Berry: each upstream test file, with a sentinel appended after its final assertion -------------
cd "$BERRY_DIR"
for t in tests/*.be; do
  name="$(basename "$t" .be)"
  # checkspace.be fails on this old commit upstream: default/be_re_lib.c contains a tab character.
  if [ "$name" = checkspace ]; then skipped=$((skipped + 1)); continue; fi
  { cat "$t"; printf '\nprint("%s")\n' "$SENTINEL"; } > "$work/$name.be"
  out="$(timeout 120 "$BERRY_BIN" "$work/$name.be" 2>&1)"; rc=$?
  if [ $rc -eq 0 ] && [ "$(printf '%s\n' "$out" | tail -n 1)" = "$SENTINEL" ]; then pass; else fail "tests/$name.be rc=$rc: $(printf '%s' "$out" | tail -n 3)"; fi
done

# --- Berry: direct known-answer probes of the interpreter --------------------------------------------
berry_expect() {  # berry_expect <expected stdout> <script text>
  local want="$1" got
  got="$(timeout 20 "$BERRY_BIN" -e "$2" 2>&1)"
  if [ "$got" = "$want" ]; then pass; else fail "berry -e '$2' => '$got' (want '$want')"; fi
}
berry_expect '3' 'print(1+2)'
berry_expect '[1, 2, 3]' 'print([1,2,3])'
berry_expect '{"a":1}' 'import json  print(json.dump({"a":1}))'
berry_expect '12' 'import json  print(json.load("{\"x\":[10,2]}")["x"].size() * 6)'
berry_expect '55' 'def fib(n) return n < 2 ? n : fib(n-1) + fib(n-2) end print(fib(10))'
berry_expect '007' 'import string  print(string.format("%03d", 7))'
berry_expect '7 3' 'print(7, 3)'
berry_expect '1024' 'print(1 << 10)'

emit_ctrf "tasmota" "$passed" "$failed" "$skipped"
