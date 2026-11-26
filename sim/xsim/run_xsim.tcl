# Run one program on the Culsans SoC in Vivado's simulator (XSim).
#
# From the repository root, in a Windows command prompt or the Vivado Tcl shell:
#   vivado -mode batch -source sim/xsim/run_xsim.tcl -tclargs <program.hex> [max_cycles]
#
# The first run compiles everything (several minutes); later runs reuse the
# project in build/xsim and only re-simulate. Results: build/xsim/<name>.log
set repo [file normalize [file join [file dirname [info script]] .. ..]]
cd $repo
if {[llength $argv] < 1} { error "usage: -tclargs <program.hex> \[max_cycles\]" }
set hex  [file normalize [lindex $argv 0]]
set maxc [expr {[llength $argv] > 1 ? [lindex $argv 1] : 50000000}]
set name [file rootname [file tail $hex]]
set flist build/filelists/culsans_xsim.tcl
if {![file exists $flist]} { error "$flist missing: run scripts/setup_wsl.sh in WSL first" }

set proj_dir build/xsim/proj
if {[file exists $proj_dir/culsans_xsim.xpr]} {
  open_project $proj_dir/culsans_xsim.xpr
} else {
  # The part only matters for synthesis; any part works for simulation.
  create_project culsans_xsim $proj_dir -part xc7k325tffg900-2 -force
  # keep the authors' compile order (packages first) instead of Vivado's auto-ordering
  set_property source_mgmt_mode None [current_project]
  source $flist
  set fs [get_filesets sim_1]
  # gen_filelists.py writes the file list into $culsans_sv / $culsans_vhdl
  add_files -fileset sim_1 -norecurse $culsans_sv
  if {[llength $culsans_vhdl]} { add_files -fileset sim_1 -norecurse $culsans_vhdl }
  set_property file_type SystemVerilog [get_files -of_objects $fs -filter {FILE_TYPE == Verilog}]
  set_property include_dirs $culsans_incdirs $fs
  if {[llength $culsans_defines]} { set_property verilog_define $culsans_defines $fs }
  set_property top tb_culsans $fs
  set_property top_lib xil_defaultlib $fs
  set_property -name {xsim.elaborate.debug_level} -value {off} -objects $fs
  set_property -name {xsim.simulate.log_all_signals} -value {false} -objects $fs
  set_property -name {xsim.simulate.runtime} -value {-all} -objects $fs
}
set fs [get_filesets sim_1]
set_property -name {xsim.simulate.xsim.more_options} -value "-testplusarg HEX=$hex -testplusarg MAX_CYCLES=$maxc" -objects $fs
launch_simulation -simset sim_1 -mode behavioral
set log [glob -nocomplain $proj_dir/culsans_xsim.sim/sim_1/behav/xsim/simulate.log]
file mkdir build/xsim
if {$log ne ""} { file copy -force $log build/xsim/$name.log }
foreach line [split [read [open build/xsim/$name.log]] "\n"] {
  if {[string match {*\[tb\]*} $line]} { puts $line }
}
close_sim -quiet
close_project
