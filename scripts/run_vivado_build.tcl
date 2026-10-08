# ==============================================================================
# scripts/run_vivado_build.tcl
# Non-interactive automated Vivado script to synthesize, implement, and
# generate bitstream for PicoRV32 Minimal SoC on XC7S50CSGA324-1.
# ==============================================================================

# Target FPGA Part: Xilinx Spartan-7 XC7S50CSGA324-1
set TARGET_PART "xc7s50csga324-1"
if {[info exists ::env(FPGA_PART)]} {
    set TARGET_PART $::env(FPGA_PART)
}

puts "=================================================="
puts " Building PicoRV32 SoC for FPGA Part: $TARGET_PART"
puts "=================================================="

set ROOT_DIR [file normalize [file join [file dirname [info script]] ".."]]

# Create in-memory project
create_project -in_memory -part $TARGET_PART

# Add RTL Design Sources
read_verilog -sv [file join $ROOT_DIR "rtl" "picorv32.v"]
read_verilog -sv [file join $ROOT_DIR "rtl" "uart_tx.v"]
read_verilog -sv [file join $ROOT_DIR "rtl" "simple_uart.v"]
read_verilog -sv [file join $ROOT_DIR "rtl" "bram.v"]
read_verilog -sv [file join $ROOT_DIR "rtl" "soc.v"]
read_verilog -sv [file join $ROOT_DIR "rtl" "picorv32_top.v"]

# Add Constraints configured for XC7S50CSGA324-1
read_xdc [file join $ROOT_DIR "constraints" "picorv32_uart.xdc"]

# 1. Synthesis
puts "\n---> Running Synthesis..."
synth_design -top picorv32_top -part $TARGET_PART

# 2. Optimization & Placement
puts "\n---> Running Logic Optimization & Placement..."
opt_design
place_design

# 3. Routing
puts "\n---> Running Routing..."
route_design

# 4. Generate Memory Info & Bitstream
puts "\n---> Writing Bitstream & Memory Map Info..."
write_bitstream -force [file join $ROOT_DIR "picorv32_top.bit"]
catch { write_mem_info -force [file join $ROOT_DIR "picorv32_top.mmi"] }

puts "\n=================================================="
puts " Bitstream successfully generated: picorv32_top.bit"
puts " Target Part: $TARGET_PART"
puts "=================================================="
