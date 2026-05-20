# Vivado TCL build script for the happyhop FPGA prototype.
# Builds a bitstream for the Arty A7 35T.
#
# Run from anywhere (paths are resolved relative to this script):
#     vivado -mode batch -source fpga/build.tcl
#
# Output: fpga/build/happyhop.runs/impl_1/arty_top.bit

set proj_name "happyhop"
set part      "xc7a35ticsg324-1L"   ;# Arty A7 35T part number
set top       "arty_top"

set repo_root [file normalize [file dirname [info script]]/..]
set build_dir "$repo_root/fpga/build"

# Recreate the project from scratch so the build is reproducible.
create_project -force $proj_name $build_dir -part $part

add_files -fileset sources_1 [list \
    "$repo_root/src/vga_sync.v" \
    "$repo_root/src/pixel_logic.v" \
    "$repo_root/src/tt_um_happyhop.v" \
    "$repo_root/fpga/arty_top.v" \
]
set_property top $top [get_filesets sources_1]

add_files -fileset constrs_1 "$repo_root/fpga/arty_a7.xdc"

# Synthesize.
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Implement and write bitstream.
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

set bit_path "$build_dir/$proj_name.runs/impl_1/${top}.bit"

puts ""
puts "================================================================"
puts "Build complete."
puts "Bitstream: $bit_path"
puts "Flash with: vivado -mode batch -source fpga/flash.tcl"
puts "================================================================"
