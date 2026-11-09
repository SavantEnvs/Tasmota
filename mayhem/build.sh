#!/usr/bin/env bash
#
# mayhem/build.sh — build Tasmota's host-testable C/C++ libraries for fuzzing, plus the oracle.
#
# Runs inside the commit image (mayhem/Dockerfile) as `mayhem` in /mayhem, offline and re-runnable.
# Tasmota is ESP8266/ESP32 firmware (Arduino/PlatformIO); the pure-C/C++ pieces that run on a host are
# the Berry scripting language (lib/libesp32/berry), the ccronexpr cron parser, the jsmn-shadinger JSON
# tokenizer and the Unishox string compressor. Each is built here with sanitizers; none needs a network.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"
M="$SRC/mayhem"
LIB="$SRC/lib"
BERRY="$LIB/libesp32/berry"
# Unishox moved from Unishox-1.0-shadinger to Unishox-Tasmota-1.0 after this commit.
UNISHOX="$LIB/default/Unishox-Tasmota-1.0"
[ -d "$UNISHOX" ] || UNISHOX="$LIB/default/Unishox-1.0-shadinger"
B="$M/build"              # gitignored by upstream's `build` pattern; recreated on every run
rm -rf "$B" && mkdir -p "$B/berry" "$B/lib"

# ---------------------------------------------------------------------------------------------------
# 1) Oracle build: upstream's own Berry `make`, NORMAL flags, no sanitizers. It leaves the `berry`
#    interpreter in lib/libesp32/berry (gitignored) for mayhem/test.sh to drive.
# ---------------------------------------------------------------------------------------------------
make -C "$BERRY" -j"$MAYHEM_JOBS" CC="$CC $COVERAGE_FLAGS" >"$B/berry-oracle.log" 2>&1 || { tail -30 "$B/berry-oracle.log" >&2; exit 1; }

# Known-answer self-test for ccronexpr / jsmn / Unishox, also NORMAL flags.
$CC -O2 $COVERAGE_FLAGS -c "$LIB/libesp32/ccronexpr/ccronexpr.c" -I"$LIB/libesp32/ccronexpr" -o "$B/lib/ccronexpr-oracle.o"
$CXX -O2 $COVERAGE_FLAGS -I"$LIB/libesp32/ccronexpr" -I"$LIB/default/jsmn-shadinger-1.0/src" \
    -I"$UNISHOX/src" -I"$M/stubs" \
    "$M/selftest.cpp" "$B/lib/ccronexpr-oracle.o" \
    "$LIB/default/jsmn-shadinger-1.0/src/jsmn.cpp" "$UNISHOX/src/unishox.cpp" \
    -o "$M/selftest"

# ---------------------------------------------------------------------------------------------------
# 2) Sanitized Berry. Same sources as upstream's Makefile (SRCPATH), except that default/be_port.c
#    (real stdio/filesystem) and default/berry.c (the REPL main) are replaced by mayhem/harnesses/berry_port.c.
#    Berry's constant tables come from its own `coc` generator, run out of tree.
# ---------------------------------------------------------------------------------------------------
GEN="$B/berry/generate"
mkdir -p "$GEN"
(cd "$BERRY" && python3 tools/coc/coc -o "$GEN" src default ../re1.5 ../berry_mapping/src ../berry_int64/src -c default/berry_conf.h)

BERRY_INC=(-I"$BERRY/src" -I"$BERRY/default" -I"$LIB/libesp32/re1.5" -I"$LIB/libesp32/berry_mapping/src" -I"$LIB/libesp32/berry_int64/src" -I"$GEN")
BERRY_CFLAGS=(-std=c99 -O2 -ffp-contract=off -DUSE_BERRY_INT64 -w $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link)

SRCS=()
for d in "$BERRY/src" "$BERRY/default" "$LIB/libesp32/re1.5" "$LIB/libesp32/berry_mapping/src" "$LIB/libesp32/berry_int64/src"; do
  for f in "$d"/*.c; do
    case "$f" in */default/be_port.c|*/default/berry.c) continue ;; esac
    SRCS+=("$f")
  done
done
SRCS+=("$M/harnesses/berry_port.c")

OBJS=()
for f in "${SRCS[@]}"; do
  o="$B/berry/$(echo "${f#"$SRC"/}" | tr '/' '_').o"
  OBJS+=("$o")
  while [ "$(jobs -rp | wc -l)" -ge "$MAYHEM_JOBS" ]; do wait -n; done
  extra=()
  # be_gc.c premark_global() forms `data + 0` on the NULL vector of a VM that never set up its globals
  # (benign, but it fires on every failed bytecode load); that one UBSan check is relaxed for this one file.
  case "$f" in */berry/src/be_gc.c) extra=(-fno-sanitize=pointer-overflow) ;; esac
  $CC "${BERRY_CFLAGS[@]}" "${extra[@]}" "${BERRY_INC[@]}" -c "$f" -o "$o" &
done
wait   # a failed compile makes the object missing, so the link below fails loudly (set -e does not see `&` jobs)
for o in "${OBJS[@]}"; do [ -s "$o" ] || { echo "missing object $o" >&2; exit 1; }; done

# ---------------------------------------------------------------------------------------------------
# 3) Harness: each linked twice — with libFuzzer, and with the run-once driver as a standalone reproducer.
#    lsan_off.cc turns LeakSanitizer off at build time (leaks are not what this fleet fuzzes for).
# ---------------------------------------------------------------------------------------------------
$CXX $SANITIZER_FLAGS -c "$M/lsan_off.cc" -o "$B/lsan_off.o"
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$B/standalone_main.o"

link() {  # link <name> <harness-source> <compiler> <include flags...> -- <objects...>
  local name="$1" src="$2" cc="$3"; shift 3
  local inc=() objs=()
  while [ "$1" != "--" ]; do inc+=("$1"); shift; done; shift
  objs=("$@")
  local base=($SANITIZER_FLAGS $DEBUG_FLAGS -O1)
  if [ "$cc" = "$CC" ]; then base+=(-std=c99); fi
  "$cc" "${base[@]}" $LIB_FUZZING_ENGINE "${inc[@]}" "$src" "${objs[@]}" "$B/lsan_off.o" -lm -ldl -o "/mayhem/$name"
  "$cc" "${base[@]}" "${inc[@]}" "$src" "$B/standalone_main.o" "${objs[@]}" "$B/lsan_off.o" -lm -ldl -o "/mayhem/$name-standalone"
}

link berry_run      "$M/harnesses/berry_run.c"      "$CC" "${BERRY_INC[@]}" -DUSE_BERRY_INT64 -- "${OBJS[@]}"
