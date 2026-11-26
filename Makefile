# Culsans replication: top-level entry points. Run from Ubuntu (WSL2) in the repo root.
#
#   make setup         fetch the authors' sources, write overlays and file lists
#   make sw            build the authors' integration tests (build/sw/integration/*.hex)
#   make verilator     build the fast Verilator model (optional, build/verilator/Vtb_culsans)
#   make verilator-bench  same, with all DRAM coherent (benchmarks; build/verilator_bench/)
#   make run HEX=...   run one program on the Verilator model
#   make regress       run every integration test on the Verilator model
#
# Vivado (Windows) uses the same file lists: see README.md, "Simulate in Vivado" and
# "Synthesize in Vivado" (synth/synth_culsans.tcl reads build/filelists/culsans_fpga.tcl).

SHELL := /bin/bash
VERILATOR ?= verilator
JOBS      ?= 4
O         := build/overlay
FL        := build/filelists

# authors' file ordering + simulation-only extras shared by both simulators
GEN_COMMON := --exclude culsans_test.sv \
  --extra culsans/modules/cva6/corev_apu/tb/common/mock_uart.sv \
  --extra sim/common/culsans_logger_stubs.sv \
  --extra sim/tb/tb_culsans.sv \
  --replace cv64a6_imafdc_sv39_wb_config_pkg.sv=$(O)/cv64a6_imafdc_sv39_wb_config_pkg.sv \
  --replace cva6.sv=$(O)/cva6.sv \
  --replace rvfi_tracer.sv=$(O)/rvfi_tracer.sv \
  --define CULSANS_NO_TRACE

setup: submodules filelists

submodules:
	git -c url."https://github.com/".insteadOf=git@github.com: submodule update --init culsans
	cd culsans && git -c url."https://github.com/".insteadOf=git@github.com: \
	  submodule update --init --recursive modules/cva6 modules/axi_llc

filelists:
	python3 scripts/make_overlays.py
	mkdir -p $(FL)
	RISCV=/usr $(MAKE) -s -f scripts/flist.mk CULSANS=culsans print > $(FL)/authors_order.txt 2>/dev/null
	python3 scripts/gen_filelists.py $(FL)/authors_order.txt $(GEN_COMMON) --name culsans_xsim
	python3 scripts/gen_filelists.py $(FL)/authors_order.txt $(GEN_COMMON) \
	  --replace sub_per_hash.sv=$(O)/sub_per_hash.sv --name culsans_verilator
	RISCV=/usr $(MAKE) -s -f scripts/flist.mk CULSANS=culsans target=cv64a6_imafdch_sv39_wb print-fpga \
	  > $(FL)/authors_fpga_order.txt 2>/dev/null
	python3 scripts/gen_filelists.py $(FL)/authors_fpga_order.txt --name culsans_fpga \
	  --exclude corev_apu/tb/ariane_peripherals.sv \
	  --replace cv64a6_imafdch_sv39_wb_config_pkg.sv=$(O)/cv64a6_imafdch_sv39_wb_config_pkg.sv

sw:
	$(MAKE) -C sw integration

VFLAGS := -f $(FL)/culsans_verilator.f culsans/modules/cva6/verilator_config.vlt \
	  --top-module tb_culsans --binary --timing --unroll-count 256 -O3 \
	  --x-assign fast --x-initial fast \
	  -Wno-fatal -Wno-lint -Wno-style -Wno-UNOPTFLAT -Wno-BLKANDNBLK -Wno-MULTIDRIVEN \
	  -Wno-TIMESCALEMOD -Wno-ENUMVALUE -j $(JOBS)

# authors' memory map (integration tests)
verilator: $(FL)/culsans_verilator.f
	$(VERILATOR) $(VFLAGS) --Mdir build/verilator

# whole DRAM coherent, as on the FPGA/Linux system (benchmarks)
verilator-bench: $(FL)/culsans_verilator.f
	$(VERILATOR) $(VFLAGS) -GALL_COHERENT=1 --Mdir build/verilator_bench

HEX        ?=
MAX_CYCLES ?= 50000000
run:
	@test -n "$(HEX)" || (echo "usage: make run HEX=build/sw/integration/<test>.hex"; false)
	mkdir -p build/run/$(notdir $(basename $(HEX)))
	cd build/run/$(notdir $(basename $(HEX))) && \
	  ../../verilator/Vtb_culsans +HEX=$(abspath $(HEX)) +MAX_CYCLES=$(MAX_CYCLES) | tee sim.log

regress:
	scripts/regress.sh build/sw/integration $(JOBS)

.PHONY: setup submodules filelists sw verilator verilator-bench run regress
