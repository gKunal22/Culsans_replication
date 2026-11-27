# Differences from the Culsans paper

State on 2026-11-27, all 11 benchmarks done (raw numbers in `bench_results.csv`). IDs refer to `ASSUMPTIONS.md`.

## 1. Design (RTL)
| # | Paper | Ours | Effect on results |
|---|---|---|---|
| A1 | RTL at paper time (unpublished snapshot) | Newest public commit `pulp-platform/culsans@a3d7416` (Mar 2024) | Small; may differ from the exact RTL they measured |
| A2 | Culsans inside the Cheshire SoC | The repo's own SoC `culsans_top` (Cheshire version not public) | Different interconnect and peripherals around the same cluster |
| A3 | Linux-capable CVA6 | RV64GC `cv64a6_imafdc_sv39_wb` for benchmarks; `imafdch` (adds hypervisor) for FPGA, as in the authors' FPGA flow | None on the benchmarks |
| A4 | 16 kB WB D-cache | 16 kB; 8-way and 128-bit lines are our choice (paper silent; repo default is 32 kB) | Hit rates depend on this |
| A7 | Coherent I-cache optional | Off | None (no self-modifying code) |

## 2. Benchmark setup
| # | Paper | Ours | Effect on results |
|---|---|---|---|
| A10 | Splash-3, OS not stated (probably Linux) | Bare metal, one thread per core, our own lock/barrier library | No OS noise, page faults or TLB misses from an OS |
| A11 | Default inputs (assumed) | Reduced inputs: FFT 2^12 points, Radix 16k keys, LU 64x64, Ocean 34x34, Barnes/FMM 256 bodies, Water 64 molecules, Radiosity test scene, Cholesky lshp | Data fits in caches more often, so fewer stalls (see section 4) |
| A9 | Memory latency not stated | Main memory is a zero-delay SRAM model | Misses to memory are cheaper than on real DRAM |
| A14 | Simulator not stated | Verilator 5.030 for benchmarks, XSim for tests | None on cycle counts (same RTL) |
| A12 | OpenPiton bars in Fig. 4 | Not re-run; we compare only the Culsans 2-core vs 1-core speedup | The headline "+32.87% vs OpenPiton" cannot be re-measured |
| — | Stalls/instr definition not stated | Issue-stall cycles per committed instruction in the region of interest | Definition may differ from theirs |

## 3. FPGA / synthesis
| # | Paper | Ours | Effect |
|---|---|---|---|
| A13 | CCU = 1.6% of area in GF22 silicon | Not done (agreed); FPGA utilization instead (CCU = 2.5% of LUTs) | Not comparable |
| A17 | No FPGA numbers in the paper | Genesys 2 part, 50 MHz, hierarchy kept, no retiming, SoC and core synthesized separately, Ethernet removed, debug ILAs removed, XPM RAM optimization off | Utilization about 1% over the device; the authors' flattened flow would be smaller |
| A17 | — | Synthesis only, no place and route or bitstream (no board) | Timing is a pre-route estimate |

## 4. Results that differ
| Benchmark | Speedup 2v1 ours / paper* | Stalls/instr ours / paper | Mem ops/instr ours / paper |
|---|---|---|---|
| Ocean | 2.05 / 1.78 | **1.66 / 3.05** | 0.32 / 0.35 |
| Barnes | 1.94 / 1.96 | 0.63 / 0.67 | 0.41 / 0.44 |
| Cholesky | **1.49 / 1.62** | 0.87 / 1.07 | 0.34 / 0.28 |
| Radiosity | **1.73 / 1.95** | 0.48 / 0.48 | 0.37 / 0.35 |
| FMM | **1.53 / 1.89** | 0.72 / 0.60 | 0.25 / 0.21 |
| Water Nsq | 1.97 / 1.94 | 0.81 / 0.90 | 0.31 / 0.31 |
| LU NC | **1.64 / 1.86** | **0.79 / 3.66** | 0.37 / 0.36 |
| Water Sp | 2.00 / 1.99 | 0.84 / 0.69 | 0.29 / 0.32 |
| LU Cont | 1.83 / 1.93 | **0.61 / 0.97** | 0.37 / 0.36 |
| FFT | 1.80 / 1.82 | 1.48 / 1.50 | 0.28 / 0.28 |
| Radix | 1.78 / 1.85 | **1.87 / 2.35** | 0.22 / 0.23 |

\* Paper speedups are read off Fig. 4 by eye (the paper prints no values), so about ±0.05.

- Mem ops/instr match everywhere (within 0.06), so the programs do the same work.
- Stalls are lower in Ocean, LU NC, LU Cont and Radix: their reduced inputs fit in the 16 kB L1 / 128 kB LLC, and memory has no delay (A9, A11).
- Ocean beats the paper's 2-core speedup (2.05, slightly superlinear) for the same reason: each core's half of the grid fits in its own L1.
- Cholesky, Radiosity, LU NC and FMM scale worse than the paper: with small inputs, locks and barriers are a bigger share of the run.
