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

# RUN the upstream cargo test suite (bit-vec + bit-set + bit-matrix, all feature-gated
# serialization suites enabled). build.sh already compiled it with `cargo test --no-run`
# using the same (normal, non-fuzzing) flags, so this only runs the pre-built binaries.
export PATH="/opt/toolchains/rust/cargo/bin:$PATH"
unset RUSTFLAGS

LOG="/tmp/cargo-test.log"
env -u RUSTFLAGS cargo test \
  -p bit-vec -p bit-set -p bit-matrix \
  --features "bit-vec/serde,bit-vec/borsh,bit-vec/miniserde,bit-set/serde,bit-set/borsh,bit-set/miniserde,bit-matrix/serde,bit-matrix/borsh,bit-matrix/miniserde" \
  2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}

# Sum every per-suite summary line: "test result: ok. X passed; Y failed; Z ignored; ..."
read -r PASSED FAILED SKIPPED <<<"$(awk '
  /^test result:/ {
    for (i=1;i<=NF;i++) {
      if ($(i+1) ~ /^passed/)  p += $i;
      if ($(i+1) ~ /^failed/)  f += $i;
      if ($(i+1) ~ /^ignored/) s += $i;
    }
  }
  END { printf "%d %d %d", p+0, f+0, s+0 }' "$LOG")"

# Honesty guards: a cargo that dies (or is neutered) parses as 0 tests — that is a failure,
# and a non-zero cargo exit with 0 parsed failures is forced to a failure too.
if [ "$(( PASSED + FAILED + SKIPPED ))" -eq 0 ]; then FAILED=1; fi
if [ "$rc" -ne 0 ] && [ "$FAILED" -eq 0 ]; then FAILED=1; fi

emit_ctrf "cargo-test" "$PASSED" "$FAILED" "$SKIPPED"
