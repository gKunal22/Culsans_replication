# Prints the ordered RTL file list of the Culsans SoC (culsans_top) as used by
# the authors' tests/rtl.mk, without requiring QuestaSim or gcc-8.
# Usage: make -s -f scripts/flist.mk CULSANS=culsans print
CULSANS ?= culsans
CULSANS_ABS := $(abspath $(CULSANS))
target ?= cv64a6_imafdc_sv39_wb
export XCELIUM_HOME=/dev/null
include $(CULSANS_ABS)/modules/cva6/Makefile
CVA6_DIR := $(root-dir)

LLC_DIR := $(CULSANS_ABS)/modules/axi_llc
LLC_PKG := $(addprefix $(LLC_DIR)/src/, axi_llc_pkg.sv axi_llc_reg_pkg.sv)
LLC_SRC := $(addprefix $(LLC_DIR)/src/, axi_llc_burst_cutter.sv axi_llc_data_way.sv axi_llc_merge_unit.sv \
  axi_llc_read_unit.sv axi_llc_reg_top.sv axi_llc_write_unit.sv eviction_refill/axi_llc_ax_master.sv \
  eviction_refill/axi_llc_r_master.sv eviction_refill/axi_llc_w_master.sv hit_miss_detect/axi_llc_evict_box.sv \
  hit_miss_detect/axi_llc_lock_box_bloom.sv hit_miss_detect/axi_llc_miss_counters.sv \
  hit_miss_detect/axi_llc_tag_pattern_gen.sv axi_llc_chan_splitter.sv axi_llc_evict_unit.sv \
  axi_llc_refill_unit.sv axi_llc_ways.sv hit_miss_detect/axi_llc_tag_store.sv axi_llc_config.sv \
  axi_llc_hit_miss.sv axi_llc_top.sv axi_llc_reg_wrap.sv)

CUL_RTL := $(CULSANS_ABS)/rtl
CUL_PKG := $(wildcard $(CUL_RTL)/include/*_pkg.sv)
CUL_SRC := $(addprefix $(CVA6_DIR)vendor/planv/ace/src/, ace_intf.sv snoop_intf.sv ccu_fsm.sv ace_trs_dec.sv ace_ccu_top.sv)
CUL_SRC += $(filter-out %/culsans_xilinx.sv, $(wildcard $(CUL_RTL)/src/*.sv))

print:
	@echo "#TARGET $(target)"
	@echo "#CVA6_REPO_DIR $(abspath $(CVA6_DIR))"
	@echo "#INCDIR $(subst +incdir+,,$(list_incdir)) $(LLC_DIR)/include $(CUL_RTL)/include"
	@for f in $(flists); do echo "#FLIST $$f"; done
	@for f in $(filter %.sv,$(ariane_pkg)); do echo "PKG $$f"; done
	@for f in $(filter %.sv,$(src)); do echo "SRC $$f"; done
	@for f in $(filter %.vhd,$(uart_src)); do echo "VHD $$f"; done
	@for f in $(LLC_PKG) $(LLC_SRC); do echo "LLC $$f"; done
	@for f in $(CUL_PKG) $(CUL_SRC); do echo "CUL $$f"; done

# File list of the FPGA top (culsans_xilinx), in the order of culsans/fpga/Makefile
# (scripts/add_sources.tcl recipe), with the same fpga_filter. Use target=cv64a6_imafdch_sv39_wb.
FPGA_FILTER := $(fpga_filter) $(addprefix $(CVA6_DIR), corev_apu/fpga/src/ariane_xilinx.sv) \
  $(wildcard $(addprefix $(CVA6_DIR), corev_apu/tb/ariene_*.sv))
CUL_FPGA := $(addprefix $(CVA6_DIR)vendor/planv/ace/src/, ace_intf.sv snoop_intf.sv ccu_fsm.sv ace_trs_dec.sv ace_ccu_top.sv) \
  $(CUL_RTL)/src/culsans_xilinx.sv

print-fpga:
	@echo "#TARGET $(target)"
	@echo "#CVA6_REPO_DIR $(abspath $(CVA6_DIR))"
	@echo "#INCDIR $(CVA6_DIR)vendor/pulp-platform/common_cells/include $(CVA6_DIR)vendor/pulp-platform/axi/include \
	  $(CVA6_DIR)vendor/planv/ace/include $(LLC_DIR)/include $(CVA6_DIR)corev_apu/register_interface/include"
	@for f in $(filter %.vhd,$(uart_src)); do echo "VHD $$f"; done
	@for f in $(LLC_PKG) $(filter %.sv,$(ariane_pkg)) $(filter-out $(FPGA_FILTER),$(src_flist)) \
	  $(filter-out $(FPGA_FILTER),$(filter %.sv,$(src))) $(CUL_PKG) $(filter-out $(FPGA_FILTER),$(fpga_src)) \
	  $(LLC_SRC) $(CUL_FPGA); do echo "SRC $$f"; done
