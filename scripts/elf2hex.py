#!/usr/bin/env python3
"""Convert a RISC-V ELF into a $readmemh image of 64-bit words for tb_culsans.

Word 0 of the image is address BASE (default 0x8000_0000, start of DRAM).
Usage: elf2hex.py prog.elf prog.hex [--base 0x80000000] [--objcopy riscv64-unknown-elf-objcopy]
"""
import argparse, subprocess, tempfile, os

ap = argparse.ArgumentParser()
ap.add_argument("elf"); ap.add_argument("hex")
ap.add_argument("--base", type=lambda x: int(x, 0), default=0x80000000)
ap.add_argument("--objcopy", default="riscv64-unknown-elf-objcopy")
a = ap.parse_args()

with tempfile.TemporaryDirectory() as d:
    vh = os.path.join(d, "img.vh")
    subprocess.check_call([a.objcopy, "-O", "verilog", a.elf, vh])
    mem = {}
    addr = 0
    for line in open(vh):
        line = line.strip()
        if not line:
            continue
        if line.startswith("@"):
            addr = int(line[1:], 16)
            continue
        for b in line.split():
            mem[addr] = int(b, 16)
            addr += 1
lo = a.base
hi = max(mem) + 1
nwords = (hi - lo + 7) // 8
with open(a.hex, "w") as f:
    for w in range(nwords):
        v = 0
        for i in range(8):
            v |= mem.get(lo + 8 * w + i, 0) << (8 * i)
        f.write(f"{v:016x}\n")
print(f"{a.hex}: {nwords} words ({nwords*8/1024:.1f} KiB) from 0x{lo:x}")
