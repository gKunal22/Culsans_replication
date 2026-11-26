#!/usr/bin/env bash
# Build one Splash-3 benchmark as a bare-metal image for the Culsans SoC.
#   sw/bench/build.sh <bench> <nproc>     e.g. sw/bench/build.sh fft 2
# Output: build/bench/<bench>_p<nproc>.hex (+ .elf, .dis)
# Benchmarks, their arguments and input files are listed in sw/bench/benchmarks.conf.
set -euo pipefail
bench=$1; np=$2
root=$(realpath "$(dirname "$0")/../..")
conf=$root/sw/bench/benchmarks.conf
splash=$root/third_party/Splash-3/codes
rt=$root/sw/bench/rt
out=${OUT:-$root/build/bench}
prefix=${PREFIX:-riscv64-unknown-elf-}

field() { awk -F'|' -v b="$bench" -v n="$1" '{gsub(/^[ \t]+|[ \t]+$/, "", $1)} $1==b {x=$n; gsub(/^[ \t]+|[ \t]+$/, "", x); print x}' "$conf"; }
dir=$(field 2)
[ -n "$dir" ] || { echo "unknown benchmark '$bench' (see $conf)"; exit 1; }
args=$(field 3); args=${args//@P@/$np}
stdin_file=$(field 4)
files=$(field 5)
extra_dirs=$(field 6)

src=$out/src/${bench}_p$np
rm -rf "$src"; mkdir -p "$src"
cp -r "$splash/$dir"/. "$src"/
cd "$src"
# size changes some benchmarks need to fit the simulated memory: sw/bench/patches/<bench>.sed
patch=$root/sw/bench/patches/$bench.sed
if [ -f "$patch" ]; then for f in *.in; do sed -i -f "$patch" "$f"; done; fi
# PARMACS expansion, exactly as Splash-3's Makefile.config does it, with our macros
# headers may include each other through m4, so expand until every one succeeds
for pass in 1 2 3 4 5; do
  ok=1
  for f in *.h.in; do [ -e "$f" ] || continue
    m4 -Ulen -Uindex "$rt/baremetal.m4" "$f" > "${f%.in}" 2>/dev/null || ok=0
  done
  [ $ok = 1 ] && break
done
for f in *.c.in; do m4 -Ulen -Uindex "$rt/baremetal.m4" "$f" > "${f%.in}"; done

# our input files may contain @P@ (number of harts); Splash-3's own are used as shipped
inpath() {
  case $1 in
    splash:*) echo "$splash/${1#splash:}";;
    *) sed "s/@P@/$np/g" "$root/sw/bench/inputs/$1" > "$src/$1"; echo "$src/$1";;
  esac
}
embed=()
[ -n "$stdin_file" ] && embed+=(--stdin "$(inpath "$stdin_file")")
for f in $files; do embed+=("$(inpath "$f")"); done
python3 "$rt/embed_files.py" "$src/bm_inputs.c" "${embed[@]}"

cflags=(-march=rv64gc_zifencei -mabi=lp64d -mcmodel=medany --specs=picolibc.specs
        -O2 -g -std=gnu11 -fno-strict-aliasing -ffunction-sections
        -D_XOPEN_SOURCE=500 -D_POSIX_C_SOURCE=200112 -DBM_ARGS="\"$bench $args\""
        -I"$rt" -I"$rt/compat" -I. -include bm.h -w ${BM_CFLAGS:-})
srcs=$(ls *.c)
for d in $extra_dirs; do srcs="$srcs $(ls $d/*.c)"; cflags+=(-I"$d"); done
${prefix}gcc "${cflags[@]}" -nostartfiles -T "$rt/link.ld" \
  "$rt/crt.S" "$rt/bm.c" $srcs ${EXTRA_SRCS:-} -lm -o "$out/${bench}_p$np.elf"
${prefix}objdump -d "$out/${bench}_p$np.elf" > "$out/${bench}_p$np.dis"
python3 "$root/scripts/elf2hex.py" --objcopy ${prefix}objcopy "$out/${bench}_p$np.elf" "$out/${bench}_p$np.hex"
