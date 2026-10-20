#!/bin/sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

run_tests() {
  FORMHAUS_HEAVY_TESTS=1 swift test
}

run_tsan() {
  FORMHAUS_HEAVY_TESTS=1 TSAN_OPTIONS=halt_on_error=1 \
    swift test --sanitize=thread --scratch-path .build/tsan --filter "sharedAutomatons|concurrentUse"
}

run_benchmarks() {
  cd "$root/Benchmarks"
  swift package benchmark
}

case ${1:-all} in
  tests) run_tests ;;
  tsan) run_tsan ;;
  benchmarks) run_benchmarks ;;
  all) run_tests && run_tsan && run_benchmarks ;;
  *)
    echo "usage: $0 [all|tests|tsan|benchmarks]" >&2
    exit 1
    ;;
esac
