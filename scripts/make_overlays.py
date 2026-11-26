#!/usr/bin/env python3
"""Create the replication's source overlays in build/overlay/.

The authors' sources under culsans/ are never edited. Where the replication
needs a different value or a simulator workaround, this script writes a
modified copy into build/overlay/, and scripts/gen_filelists.py swaps it in
for the original. Every change is listed here and in ASSUMPTIONS.md.

  cv64a6_imafdc_sv39_wb_config_pkg.sv   L1 D-cache 32 kB -> 16 kB (paper, A4)
  cv64a6_imafdch_sv39_wb_config_pkg.sv  same, for the FPGA/synthesis configuration
  sub_per_hash.sv                       Verilator only: packed arrays (tool limitation)
  cva6.sv                               instruction tracer behind `ifndef CULSANS_NO_TRACE
  rvfi_tracer.sv                        trace file and 6M-cycle auto-stop behind `ifndef CULSANS_NO_TRACE
"""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CVA6 = os.path.join(ROOT, "culsans", "modules", "cva6")
OUT = os.path.join(ROOT, "build", "overlay")
DCACHE_BYTES = 16384


def read(p):
    with open(p) as f:
        return f.read()


def sub_once(text, old, new, what):
    if text.count(old) != 1:
        sys.exit(f"make_overlays: expected exactly one '{old.strip()}' in {what}; sources changed?")
    return text.replace(old, new)


def write(name, header, text):
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "w") as f:
        f.write(header + text)
    print(f"  build/overlay/{name}")


def main():
    print("Writing overlays:")
    for cfg in ("cv64a6_imafdc_sv39_wb", "cv64a6_imafdch_sv39_wb"):
        src = os.path.join(CVA6, "core", "include", f"{cfg}_config_pkg.sv")
        t = sub_once(read(src), "localparam CVA6ConfigDcacheByteSize = 32768;",
                     f"localparam CVA6ConfigDcacheByteSize = {DCACHE_BYTES}; // replication: paper uses 16 kB",
                     src)
        write(f"{cfg}_config_pkg.sv",
              f"// Overlay of {os.path.relpath(src, ROOT)}: L1 D-cache {DCACHE_BYTES} B (assumption A4)\n", t)

    src = os.path.join(CVA6, "vendor", "pulp-platform", "common_cells", "src", "sub_per_hash.sv")
    t = read(src)
    t = sub_once(t, "typedef int unsigned perm_lists_t [NoRounds][InpWidth];",
                 "typedef logic [NoRounds-1:0][InpWidth-1:0][31:0] perm_lists_t;", src)
    t = sub_once(t, "typedef int unsigned xor_stages_t [NoRounds][InpWidth][3];",
                 "typedef logic [NoRounds-1:0][InpWidth-1:0][2:0][31:0] xor_stages_t;", src)
    t = sub_once(t, "perm_lists_t indices;", "perm_lists_t indices = '0;", src)
    t = sub_once(t, "perm_lists_t perm_array;", "perm_lists_t perm_array = '0;", src)
    t = sub_once(t, "xor_stages_t xor_array;", "xor_stages_t xor_array = '0;", src)
    write("sub_per_hash.sv",
          f"// Overlay of {os.path.relpath(src, ROOT)} for the Verilator flow:\n"
          "// packed instead of unpacked parameter arrays; identical values.\n", t)

    src = os.path.join(CVA6, "core", "cva6.sv")
    t = read(src)
    t = sub_once(t, "  //pragma translate_off\n`ifdef PITON_ARIANE",
                 "  //pragma translate_off\n`ifndef CULSANS_NO_TRACE\n`ifdef PITON_ARIANE", src)
    t = sub_once(t, "`endif // VERILATOR\n//pragma translate_on",
                 "`endif // VERILATOR\n`endif // CULSANS_NO_TRACE\n//pragma translate_on", src)
    write("cva6.sv", f"// Overlay of {os.path.relpath(src, ROOT)}: tracer can be disabled with CULSANS_NO_TRACE\n", t)

    src = os.path.join(CVA6, "corev_apu", "tb", "rvfi_tracer.sv")
    t = read(src)
    i = t.index("  logic[riscv::PLEN-1:0] TOHOST_ADDR;")
    j = t.rindex("endmodule")
    t = t[:i] + "`ifndef CULSANS_NO_TRACE\n" + t[i:j] + "`else\n  assign end_of_test_o = '0;\n`endif\n" + t[j:]
    write("rvfi_tracer.sv", f"// Overlay of {os.path.relpath(src, ROOT)}: disabled with CULSANS_NO_TRACE\n", t)


if __name__ == "__main__":
    main()
