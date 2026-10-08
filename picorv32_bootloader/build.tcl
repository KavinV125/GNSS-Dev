# build.tcl -- creates the picorv32_bootloader Vivado project and
# generates a bitstream.
#
# BEFORE running this:
#   1. Copy picorv32.v (from your downloaded YosysHQ/picorv32 repo) into
#      this same folder, next to top.v.
#   2. Build the bootloader in WSL: cd bootloader && make clean && make
#      -> produces bootloader/bootloader.hex
#   3. Copy bootloader/bootloader.hex into this same top-level folder
#      (next to top.v) -- that's the path $readmemh expects.
#
# Run from the Vivado Tcl Console with:
#   cd {D:/RISCV_FPGA/picorv32_bootloader}
#   source build.tcl

create_project picorv32_bootloader ./picorv32_bootloader_proj -part xc7s50csga324-1 -force

add_files -norecurse {top.v picorv32.v}
add_files -fileset constrs_1 -norecurse boolean_bootloader.xdc
add_files -norecurse bootloader.hex

set_property top top [current_fileset]
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "Bitstream: [glob -nocomplain ./picorv32_bootloader_proj/picorv32_bootloader_proj.runs/impl_1/*.bit]"
