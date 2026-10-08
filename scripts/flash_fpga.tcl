# ==============================================================================
# scripts/flash_fpga.tcl
# Non-interactive automated Vivado script to program the FPGA via JTAG.
# ==============================================================================

set ROOT_DIR [file normalize [file join [file dirname [info script]] ".."]]
set BIT_FILE [file join $ROOT_DIR "picorv32_top.bit"]

if {![file exists $BIT_FILE]} {
    puts "Error: Bitstream file '$BIT_FILE' not found!"
    exit 1
}

puts "=================================================="
puts " Connecting to Hardware Server & Programming FPGA "
puts "=================================================="

open_hw_manager

# Connect to local hardware server (hw_server)
if {[catch {connect_hw_server -allow_non_jtag} err]} {
    puts "Warning: connect_hw_server notice: $err"
}

# Open target device
if {[catch {open_hw_target} err]} {
    puts "Error: Unable to open hardware target. Is the FPGA plugged in and turned on?"
    puts "$err"
    close_hw_manager
    exit 1
}

# Get connected devices
set targets [get_hw_devices]
if {[llength $targets] == 0} {
    puts "Error: No JTAG hardware devices detected!"
    close_hw_target
    disconnect_hw_server
    close_hw_manager
    exit 1
}

# Select primary FPGA device (Spartan-7 xc7s, Artix-7 xc7a, Zynq xc7z, Kintex xcku)
set dev [lindex $targets 0]
foreach d $targets {
    if {[string match -nocase "*xc7s*" $d] || [string match -nocase "*xc7a*" $d] || [string match -nocase "*xc7z*" $d] || [string match -nocase "*xcku*" $d]} {
        set dev $d
        break
    }
}

puts "--> Selected Target Device: $dev"
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev

puts "--> Programming Bitstream: $BIT_FILE"
set_property PROGRAM.FILE $BIT_FILE $dev
program_hw_devices $dev

puts "\n=================================================="
puts " FPGA PROGRAMMING SUCCESSFUL! "
puts " Check PuTTY for: hello lingesh"
puts "=================================================="

close_hw_target
disconnect_hw_server
close_hw_manager
