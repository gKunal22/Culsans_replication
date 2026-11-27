# Replication assumptions

The paper (Tedeschi et al., "Culsans: An Efficient Snoop-based Coherency Unit for the CVA6 Open Source
RISC-V application processor", DSD/SEAA 2024 WiP, arXiv 2407.19895) leaves several details unstated.
Per the project decision of 2026-11-26 we do not contact the authors; every gap is closed by an
explicit assumption below. Each entry says what the paper states, what we use, and why.

| ID | Topic | Paper says | We use | Reason |
|----|-------|-----------|--------|--------|
| A1 | RTL version | Repo in footnote 1 (pulp-platform/culsans) | `pulp-platform/culsans` @ `a3d7416` (2024-03-27); `planvtech/cva6` @ `338d4c1`; `planvtech/axi_llc` @ `39355b9` | Newest public commit; it predates the paper (Jul/Aug 2024), so it is the closest available snapshot. |
| A2 | SoC around the cluster | Integrated into Cheshire | The repo's own SoC `culsans_top` (2 x CVA6, CCU, AXI crossbar, LLC, peripherals, SRAM main memory) | The public repo does not contain a Cheshire integration. |
| A3 | Core configuration | Linux-capable CVA6, WB D-cache with ACE | `cv64a6_imafdc_sv39_wb` (RV64GC, Sv39, WB coherent D-cache) | Configuration used by the authors' test flow. The FPGA flow uses `cv64a6_imafdch_sv39_wb` (adds the hypervisor extension); we use that one only for synthesis. |
| A4 | L1 D-cache size | 16 kB, write-back (Fig. 4 legend) | 16 kB, 8-way, 128-bit lines | Repo default is 32 kB; we override the size to match the paper and keep the repo's associativity and line width (paper does not state them). |
| A5 | L1 I-cache | 16 kB | 16 kB, 4-way, 128-bit lines | Repo default already matches. |
| A6 | LLC | 128 kB shared L2 (Fig. 4 legend) | `axi_llc`, 8 ways x 256 lines x 8 x 64-bit blocks = 128 kB | Repo default already matches. |
| A7 | Coherent I-cache | RTL parameter, can be turned off | Off | Splash-3 does not generate code at run time. |
| A8 | Core count | Dual-core evaluation | `NB_CORES = 2` | As in the paper. |
| A9 | Main-memory latency | Not stated | SRAM model behind `axi2mem`; fixed delay to be fixed after bring-up and recorded here | The paper's runs were on an unstated platform; we choose one value and keep it for all benchmarks. |
| A10 | Benchmark environment | Splash-3, 11 benchmarks; OS not stated | Bare metal, one thread per hart, simple barrier/lock library | Linux boot plus full runs is impractical in simulation (decision of 2026-11-26). |
| A11 | Benchmark inputs | Not stated | Reduced inputs, listed per benchmark in `bench/README.md` | Simulation time. |
| A12 | Metric | Speedup normalized to single-core Culsans | Cycles(1 core) / Cycles(2 cores) on the same RTL; single-core run = hart 1 parked | Matches Fig. 4's normalization. OpenPiton bars are taken from the paper, not re-run. |
| A13 | Area | 1.6 % of system in GF22 | Not reproduced | Not needed for this project (decision of 2026-11-26). FPGA utilization is reported instead. |
| A14 | Simulator | Not stated | Vivado XSim for functional/coherence tests; Verilator 5.030 for long benchmark runs | The dual-core SoC simulates at about 4-5 k cycles/s even in Verilator; XSim is expected to be slower. Both run the same RTL and testbench. |
| A15 | Test software | Not stated | Authors' integration tests built with GCC 13 (Ubuntu `gcc-riscv64-unknown-elf`) and picolibc headers instead of their GCC 8 + newlib; `amo_mutex` gets the register clobbers its inline assembly omits | Without the clobbers GCC 13 keeps a live value in `a0`, which the assembly overwrites, and the test takes ~10^9 cycles. |
| A16 | Simulation-only edits | n/a | Instruction tracers disabled (`CULSANS_NO_TRACE`), channel loggers replaced by no-op stand-ins, Verilator-only packed-array version of `sub_per_hash.sv` | None of these drive design signals; they only write trace files or work around tool limits. See `scripts/make_overlays.py`. |
| A17 | FPGA synthesis | Not stated (FPGA flow in the repo: Genesys 2, 50 MHz) | Authors' `culsans_xilinx` top, Genesys 2 part `xc7k325tffg900-2`, the authors' IP settings and constraints, synthesis keeping the module hierarchy and without retiming (the authors' flattened + retiming run did not finish in 10 h on a PC; still available with the `authors` option). On a 16 GB PC the whole SoC does not fit in memory, so by default the SoC is synthesized with both cores as black boxes and one core is synthesized separately with identical parameters (`synth/culsans_core_ooc.sv`); SoC totals are the sum (rest + 2 x core), and the ILA's taps into the cores are tied to 0 in that run. `full` synthesizes everything in one run. Optional place and route without bitstream (`synth/synth_culsans.tcl`) | No board yet. Digilent board files are used if installed, otherwise only the part (the IPs are configured explicitly, so this does not change them). The sim-only `corev_apu/tb/ariane_peripherals.sv` is left out because it defines the same module name as the FPGA version. The debug ILA in `culsans_xilinx` stays, as in the authors' build; it is reported as a separate line so it can be subtracted. |
