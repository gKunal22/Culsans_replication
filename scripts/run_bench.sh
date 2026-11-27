#!/usr/bin/env bash
# Build and run Splash-3 benchmarks on the all-coherent Verilator model, 1 and 2 harts.
#   [SIM=<model>] [OUT_RUNS=<dir>] scripts/run_bench.sh [jobs] [bench ...]     default: all benchmarks in sw/bench/benchmarks.conf
# Results: build/bench_runs/<bench>_p<N>/sim.log and build/bench_runs/results.csv
set -u
root=$(realpath "$(dirname "$0")/..")
jobs=${1:-4}; shift || true
benches=("$@")
[ ${#benches[@]} -gt 0 ] || mapfile -t benches < <(grep -v '^#' "$root/sw/bench/benchmarks.conf" | awk -F'|' 'NF>1{gsub(/ /,"",$1); print $1}')
sim=${SIM:-$root/build/verilator_bench/Vtb_culsans}   # SIM/OUT: e.g. the delayed-memory model
[ -x "$sim" ] || { echo "build the model first: make verilator-bench"; exit 1; }
out=${OUT_RUNS:-$root/build/bench_runs}; mkdir -p "$out"

for b in "${benches[@]}"; do for p in 1 2; do
  "$root/sw/bench/build.sh" "$b" "$p" > "$out/build_${b}_p$p.log" 2>&1 || echo "build failed: $b p$p"
done; done

for b in "${benches[@]}"; do for p in 1 2; do echo "$b $p"; done; done | \
  xargs -P "$jobs" -n 2 bash -c '
    b=$0; p=$1; d="'"$out"'/${b}_p$p"; mkdir -p "$d"; cd "$d"
    stdbuf -oL timeout 36000 "'"$sim"'" +HEX="'"$root"'/build/bench/${b}_p$p.hex" +MAX_CYCLES=${MAX_CYCLES:-400000000} > sim.log 2>&1
    echo "done $b p$p: $(grep -h "ROI cycles\|EXIT\|TIMEOUT" sim.log | tr "\n" " ")"'

python3 "$root/scripts/bench_report.py" "$out" > "$out/results.csv"
cat "$out/results.csv"
