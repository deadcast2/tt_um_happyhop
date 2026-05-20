# Vivado TCL script to flash the happyhop bitstream onto the Arty A7 over JTAG.
#
# Connect the Arty via USB, then run from anywhere:
#     vivado -mode batch -source fpga/flash.tcl
#
# This loads the bitstream into volatile config memory; it disappears on
# power-cycle. To program the onboard SPI flash so the design boots on
# power-up, use the Vivado GUI's Hardware Manager > Add Configuration Memory.

set proj_name "happyhop"
set top       "arty_top"

set repo_root [file normalize [file dirname [info script]]/..]
set bit_path  "$repo_root/fpga/build/$proj_name.runs/impl_1/${top}.bit"

if { ![file exists $bit_path] } {
    puts "ERROR: bitstream not found at $bit_path"
    puts "       Run 'vivado -mode batch -source fpga/build.tcl' first."
    exit 1
}

open_hw_manager
connect_hw_server
open_hw_target

set device [lindex [get_hw_devices] 0]
puts "Programming $device with $bit_path ..."
set_property PROGRAM.FILE $bit_path $device
program_hw_devices $device

close_hw_target
disconnect_hw_server
close_hw_manager

puts "Done. The Arty should now be driving VGA output."
