#!/usr/bin/env bash
# Run every <name>.hex in a directory on the Verilator model, JOBS at a time.
# Usage: scripts/regress.sh <hex-dir> [jobs] [max_cycles]
set -u
dir=$(realpath "$1"); jobs=${2:-4}; maxc=${3:-5000000}
root=$(realpath "$(dirname "$0")/..")
sim=$root/build/verilator/Vtb_culsans
out=$root/build/regress/$(basename "$dir")
mkdir -p "$out"
ls "$dir"/*.hex | xargs -P "$jobs" -I{} bash -c '
  n=$(basename {} .hex); mkdir -p "'"$out"'/$n"; cd "'"$out"'/$n"
  timeout 7200 "'"$sim"'" +HEX={} +MAX_CYCLES='"$maxc"' > sim.log 2>&1
  r=$(grep -h "\[tb\] \(EXIT\|TIMEOUT\)" sim.log || echo "no result (crash?)")
  printf "%-36s %s\n" "$n" "$r"' | sort | tee "$out/summary.txt"
grep -c "code=0 " "$out/summary.txt" | xargs -I{} echo "{} of $(ls "$dir"/*.hex | wc -l) passed"
