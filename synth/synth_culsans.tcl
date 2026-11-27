# Synthesize the Culsans FPGA top (culsans_xilinx, 2x CVA6 + CCU + LLC) with Vivado.
#
# This follows the authors' flow in culsans/fpga (Makefile, scripts/prologue.tcl, scripts/run.tcl,
# xilinx/*/tcl/run.tcl) for the Genesys 2 board (xc7k325tffg900-2, 50 MHz core clock), in one
# project and without make, so it runs from Vivado on Windows. Differences from the authors' flow:
#   - IPs are created in the same project instead of one project per IP (same IP settings).
#   - The Digilent board files are optional; without them the part alone is used (A17).
#   - The L1 D-cache is 16 kB (overlay of the imafdch config package, assumption A4).
#   - Implementation stops after routing (no bitstream); pass "impl" to run it.
#   - Default synthesis keeps the hierarchy and skips retiming (much faster, exact per-block numbers);
#     pass "authors" for their flattened + retiming run.
#   - Default is "split" mode: the whole SoC needs more memory than a 16 GB PC has, so the SoC is
#     synthesized with both cores as black boxes, then one core on its own (culsans_core_ooc, identical
#     parameters). SoC total = rest + 2 x core. Pass "full" to synthesize everything in one run.
#
# Prerequisite (once, in Ubuntu/WSL in the repo root): make setup
# Run (Windows cmd or Vivado Tcl shell, from the repo root):
#   vivado -mode batch -nojournal -source synth/synth_culsans.tcl                 (synthesis only)
#   in the Vivado Tcl Shell instead: cd C:/work/culsans_replication; set argv {}; source synth/synth_culsans.tcl
#   vivado -mode batch -nojournal -source synth/synth_culsans.tcl -tclargs impl   (+ place and route)
# Results: build/fpga/reports/*.rpt and build/fpga/reports/summary.txt

set repo [file normalize [file join [file dirname [info script]] ..]]
cd $repo

set part      xc7k325tffg900-2
set board     digilentinc.com:genesys2:part0:1.1
set boardName genesys2
if {![info exists argv]} { set argv {} }
set do_impl   [expr {[lsearch -exact $argv impl] >= 0}]
# authors' settings (flattened netlist + retiming) can run for many hours on a PC; by default we
# keep the hierarchy and skip retiming (A17). "authors" restores their exact synthesis settings.
set authors   [expr {[lsearch -exact $argv authors] >= 0}]
set split     [expr {[lsearch -exact $argv full] < 0}]
set jobs      [expr {[info exists ::env(NUMBER_OF_PROCESSORS)] ? $::env(NUMBER_OF_PROCESSORS) : 4}]
# a 16 GB PC runs out of memory with many parallel Vivado processes; keep it to 2
if {$jobs > 2} { set jobs 2 }

set fl  build/filelists/culsans_fpga.tcl
if {![file exists $fl]} {
  error "$fl not found. Run 'make setup' in Ubuntu (WSL) in the repo root first."
}
set out  [file normalize build/fpga]
set rpt  $out/reports
file mkdir $rpt

# the culsans/fpga/{src,constraints} folders are symlinks into CVA6; use the real paths
set cva6_fpga culsans/modules/cva6/corev_apu/fpga
set ip_src    culsans/fpga/xilinx

create_project culsans $out/proj -part $part -force
# keep synthesized IPs outside the project so a rerun reuses them
catch {config_ip_cache -use_cache_location $out/ip_cache}
if {[catch {set_property board_part $board [current_project]} err]} {
  puts "NOTE: board files for $board not installed; using part $part only."
}
set_param general.maxThreads 2
set_msg_config -id {[Synth 8-5858]} -new_severity "info"
set_msg_config -id {[Synth 8-4480]} -limit 1000

# ---- Xilinx IPs, with the authors' settings (culsans/fpga/xilinx/<ip>/tcl/run.tcl) -------------
set ips {xlnx_axi_clock_converter xlnx_axi_dwidth_converter xlnx_axi_dwidth_converter_dm_master
         xlnx_axi_dwidth_converter_dm_slave xlnx_axi_quad_spi xlnx_axi_gpio xlnx_clk_gen
         xlnx_mig_7_ddr3}
# xlnx_ila (two debug ILAs, 13 probes) is replaced by an empty module: the BASIC licence refuses it
foreach ip $ips {
  set fh [open $ip_src/$ip/tcl/run.tcl]; set text [read $fh]; close $fh
  # keep the create_ip and set_property part, drop the per-IP project and its runs
  set a [string first "create_ip" $text]
  set b [string first "generate_target" $text]
  set body [string range $text $a [expr {$b - 1}]]
  set ipName $ip
  set boardNameShort $boardName
  set ipsrc [file normalize $ip_src/$ip]
  # MIG: 'exec cp' does not exist on Windows; copy the pin/timing file into the IP folder
  regsub {exec cp mig_\$boardNameShort\.prj [^\n]*} $body \
    {file copy -force [file join $ipsrc mig_${boardNameShort}.prj] [file join [get_property IP_DIR [get_ips $ipName]] mig_a.prj]} body
  puts "== IP $ip"
  eval $body
  generate_target all [get_ips $ip]
}

# ---- RTL, in the authors' order ---------------------------------------------------------------
source $fl
# Vivado 2026.1 flags the Ethernet MAC's legacy RAMB16_S9_S36 primitives as unsupported (Netlist 29-5298)
# and synthesis then died silently in Cross Boundary and Area Optimization. Ethernet is a peripheral that
# plays no part in the paper's evaluation; we drop it as the authors' KC705/VC707 builds do (A17).
set fh [open culsans/rtl/src/culsans_xilinx.sv]; set t [read $fh]; close $fh
regsub {(`ifdef KINTEX7\s*\.InclSPI\s*\(\s*1'b1\s*\),\s*\.InclEthernet\s*\(\s*)1'b1} $t {\11'b0} t
if {$split} {
  # cores become black boxes; the debug ILA's taps inside the cores are tied to 0
  regsub -all {gen_ariane\[[0-9]\]\.i_ariane\.[A-Za-z0-9_.:\[\]]+} $t {1'b0} t
}
set fh [open $out/culsans_xilinx_synth.sv w]; puts -nonewline $fh $t; close $fh
# Vivado 2026.1 hit an internal assertion in its RAM optimizer (HOptRamOpt.cc, .ramAssert) on the
# XPM memories behind tc_sram (LLC data/tag arrays). Ask XPM for plain block RAM without its
# "unused memory" optimization; the memory contents and ports are unchanged (A17).
set fh [open culsans/modules/cva6/vendor/pulp-platform/tech_cells_generic/src/fpga/tc_sram_xilinx.sv]
set t2 [read $fh]; close $fh
regsub -all {\.MEMORY_OPTIMIZATION(\s*)\(\s*"true"\s*\)} $t2 {.MEMORY_OPTIMIZATION\1( "false" )} t2
regsub -all {\.MEMORY_PRIMITIVE(\s*)\(\s*"auto"\s*\)} $t2 {.MEMORY_PRIMITIVE\1( "block" )} t2
set fh [open $out/tc_sram_xilinx.sv w]; puts -nonewline $fh $t2; close $fh
set culsans_sv [lmap f $culsans_sv {expr {[string match */src/fpga/tc_sram_xilinx.sv $f] ? "$out/tc_sram_xilinx.sv" : $f}}]

set soc_sv {}
foreach f $culsans_sv {
  if {[string match */culsans_xilinx.sv $f]} { lappend soc_sv $out/culsans_xilinx_synth.sv
  } elseif {$split && [string match */corev_apu/tb/ariane.sv $f]} { lappend soc_sv synth/ariane_blackbox.sv
  } else { lappend soc_sv $f }
}
read_vhdl $culsans_vhdl
lappend soc_sv synth/xlnx_ila_stub.sv
read_verilog -sv $soc_sv
set_property include_dirs $culsans_incdirs [current_fileset]

set svh  $cva6_fpga/src/genesysii.svh
set regs culsans/modules/cva6/vendor/pulp-platform/common_cells/include/common_cells/registers.svh
read_verilog -sv [list $svh $regs]
set_property -dict {file_type {Verilog Header} is_global_include 1} \
  [get_files -of_objects [get_filesets sources_1] [list [file normalize $svh] [file normalize $regs]]]
set_property top culsans_xilinx [current_fileset]

add_files -fileset constrs_1 -norecurse $cva6_fpga/constraints/genesys-2.xdc
add_files -fileset constrs_1 -norecurse $cva6_fpga/constraints/ariane.xdc
update_compile_order -fileset sources_1

# ---- synthesis (authors: default strategy + retiming) ------------------------------------------
if {$authors} {
  set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]
} else {
  set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]
}
# IPs first, one at a time, each retried once (a parallel IP run can die when memory is short)
foreach ip $ips {
  set r [get_runs -quiet ${ip}_synth_1]
  if {$r eq {}} continue
  for {set try 0} {$try < 2} {incr try} {
    if {[get_property PROGRESS $r] eq "100%" && ![string match *ERROR* [get_property STATUS $r]]} break
    if {$try > 0} { reset_run $r }
    catch {launch_runs $r -jobs 1}
    catch {wait_on_run $r}
  }
  if {[get_property PROGRESS $r] ne "100%"} {
    error "IP $ip failed twice, see $out/proj/culsans.runs/${ip}_synth_1/runme.log"
  }
}
# Vivado splits synth_design over helper processes (Synth 8-7079); on Windows these stalled at 0 % CPU
# in "Cross Boundary and Area Optimization". Run the main synthesis in a single process.
set fh [open $out/synth_pre.tcl w]; puts $fh "set_param general.maxThreads 1"; close $fh
set_property STEPS.SYNTH_DESIGN.TCL.PRE [file normalize $out/synth_pre.tcl] [get_runs synth_1]
launch_runs synth_1 -jobs $jobs
catch {wait_on_run synth_1}
set soc_ok [expr {[get_property PROGRESS [get_runs synth_1]] eq "100%"}]
if {!$soc_ok && !$split} {
  error "synthesis failed, see $out/proj/culsans.runs/synth_1/runme.log"
}
file delete -force $rpt/summary.txt
if {$soc_ok} {
open_run synth_1

proc reports {tag} {
  global rpt
  check_timing -verbose                                                    -file $rpt/$tag.check_timing.rpt
  report_timing_summary -max_paths 10                                      -file $rpt/$tag.timing_summary.rpt
  report_timing -max_paths 100 -nworst 100 -delay_type max -sort_by slack  -file $rpt/$tag.timing_WORST_100.rpt
  report_utilization                                                       -file $rpt/$tag.utilization.rpt
  report_utilization -hierarchical -hierarchical_depth 6                   -file $rpt/$tag.utilization_hier.rpt
}

# one line per block of interest: LUT, FF, BRAM tiles, DSP (CCU share is what Table/Section 5 needs)
proc block_summary {tag blocks} {
  global rpt
  set fh [open $rpt/summary.txt a]
  puts $fh "# $tag  [clock format [clock seconds] -format {%Y-%m-%d %H:%M}]"
  puts $fh [format "%-58s %9s %9s %7s %5s" block LUT FF BRAM DSP]
  foreach c $blocks {
    if {$c eq {}} { set cells [get_cells -hierarchical -filter {IS_PRIMITIVE}]; set name TOTAL } else {
      # exact name match (generate names contain [] and ., which glob patterns mangle)
      set top [get_cells -quiet -hierarchical -filter [list NAME == $c]]
      if {$top eq {}} { puts $fh [format "%-58s %s" $c "(not found)"]; continue }
      current_instance -quiet $top
      set cells [get_cells -quiet -hierarchical -filter {IS_PRIMITIVE}]
      current_instance -quiet
      set name $c
    }
    set lut  [llength [filter $cells {REF_NAME =~ LUT* || REF_NAME =~ RAMD* || REF_NAME =~ RAMS* || REF_NAME =~ SRL*}]]
    set ff   [llength [filter $cells {REF_NAME =~ FD*}]]
    set b36  [llength [filter $cells {REF_NAME =~ RAMB36*}]]
    set b18  [llength [filter $cells {REF_NAME =~ RAMB18*}]]
    set dsp  [llength [filter $cells {REF_NAME =~ DSP*}]]
    puts $fh [format "%-58s %9d %9d %7.1f %5d" $name $lut $ff [expr {$b36 + 0.5*$b18}] $dsp]
  }
  set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
  puts $fh "worst setup slack (ns): $wns"
  puts $fh ""
  close $fh
}

set soc_blocks {{} i_ccu {gen_ariane[0].i_ariane} {gen_ariane[1].i_ariane}
  {gen_ariane[0].i_ariane/i_cva6/WB.i_cache_subsystem} {gen_ariane[1].i_ariane/i_cva6/WB.i_cache_subsystem}
  i_axi_llc i_axi_xbar i_ariane_peripherals i_ila_top i_ddr}
reports synth
block_summary [expr {$split ? "post-synthesis, SoC with both cores as black boxes" : "post-synthesis"}] $soc_blocks

if {$do_impl} {
  set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE RuntimeOptimized    [get_runs impl_1]
  set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE RuntimeOptimized    [get_runs impl_1]
  set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE RuntimeOptimized [get_runs impl_1]
  set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE RuntimeOptimized      [get_runs impl_1]
  set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.IS_ENABLED false    [get_runs impl_1]
  set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED false               [get_runs impl_1]
  launch_runs impl_1 -to_step route_design -jobs $jobs
  wait_on_run impl_1
  open_run impl_1
  reports impl
  block_summary "post-route" $soc_blocks
}

} else {
  set fh [open $rpt/summary.txt a]
  puts $fh "# SoC (cores as black boxes) synthesis FAILED, see $out/proj/culsans.runs/synth_1/runme.log\n"
  close $fh
}

# ---- split mode: one core on its own, same parameters as in culsans_xilinx ---------------------
if {$split} {
  close_project
  create_project culsans_core $out/proj_core -part $part -force
  set core_sv {}
  foreach f $culsans_sv { if {![string match */culsans_xilinx.sv $f]} { lappend core_sv $f } }
  lappend core_sv synth/culsans_core_ooc.sv
  read_verilog -sv $core_sv
  set_property include_dirs $culsans_incdirs [current_fileset]
  read_verilog -sv [list $svh $regs]
  set_property -dict {file_type {Verilog Header} is_global_include 1} \
    [get_files -of_objects [get_filesets sources_1] [list [file normalize $svh] [file normalize $regs]]]
  set_property top culsans_core_ooc [current_fileset]
  # the core runs on the 50 MHz clock (clk_out1 of xlnx_clk_gen) in the authors' design
  set fh [open $out/core_ooc.xdc w]; puts $fh "create_clock -period 20.000 -name clk \[get_ports clk_i\]"; close $fh
  add_files -fileset constrs_1 -norecurse $out/core_ooc.xdc
  update_compile_order -fileset sources_1
  set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]
  set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
  set_property STEPS.SYNTH_DESIGN.TCL.PRE [file normalize $out/synth_pre.tcl] [get_runs synth_1]
  launch_runs synth_1 -jobs 1
  catch {wait_on_run synth_1}
  if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    set fh [open $rpt/summary.txt a]
    puts $fh "# core synthesis FAILED, see $out/proj_core/culsans_core.runs/synth_1/runme.log"
    close $fh
    error "core synthesis failed, see $out/proj_core/culsans_core.runs/synth_1/runme.log"
  }
  open_run synth_1
  reports core_synth
  block_summary "post-synthesis, one core (culsans_core_ooc); SoC total = black-box SoC + 2 x this" \
    {{} i_ariane i_ariane/i_cva6/WB.i_cache_subsystem}
}

puts "\n==== done; reports in $rpt ===="
set fh [open $rpt/summary.txt]; puts [read $fh]; close $fh
