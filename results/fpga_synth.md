# FPGA synthesis results (Vivado 2026.1, xc7k325tffg900-2, 50 MHz, post-synthesis)

Run on 2026-11-27 with `synth/synth_culsans.tcl` in split mode (A17): the SoC with both cores as
black boxes, plus one core (`culsans_core_ooc`) synthesized out of context. Hierarchy kept, no retiming.

| Block | LUT | FF | BRAM36 | DSP |
|---|---:|---:|---:|---:|
| SoC without cores | 65,121 | 51,550 | 51.0 | 0 |
| of which CCU (`i_ccu`) | 5,052 | 5,512 | 0 | 0 |
| of which AXI crossbar | 22,148 | 21,418 | 0 | 0 |
| of which peripherals | 7,209 | 7,444 | 1.0 | 0 |
| of which DDR (MIG) | 13,494 | 8,634 | 0 | 0 |
| One core (CVA6, WB coherent D-cache) | 70,402 | 28,489 | 102.0 | 27 |
| of which cache subsystem | 12,246 | 1,557 | 102.0 | 0 |
| **Whole SoC (SoC + 2 x core)** | **205,925** | **108,528** | **255.0** | **54** |
| Device (XC7K325T) | 203,800 | 407,600 | 445 | 840 |

- CCU share of the whole SoC: 2.5 % of LUTs, 5.1 % of FFs. The paper's 1.6 % is GF22 silicon area (A13), so not directly comparable.
- Worst setup slack at 50 MHz: SoC +0.001 ns, core +1.988 ns. Both meet timing before place and route.
- The LUT total is about 1 % over the device. This is expected for a hierarchy-kept synthesis with no cross-boundary
  optimization and the cores synthesized separately (constant ports like `hart_id_i` and `boot_addr_i` are not propagated).
  The authors' flow (`authors` argument: flattened, retimed) is what fits the Genesys2 board; it needs more memory than this PC has.
