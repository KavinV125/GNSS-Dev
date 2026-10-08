## ==============================================================================
## XDC Constraints for PicoRV32 Minimal SoC
## Target FPGA: Real Digital Boolean Board (Xilinx Spartan-7 XC7S50CSGA324-1)
## File: picorv32_uart.xdc
## ==============================================================================

## -----------------------------------------------------------------------------
## 1. System Clock (100 MHz primary oscillator on pin F14)
## -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN F14 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clk]

## -----------------------------------------------------------------------------
## 2. Reset Pushbutton (Active-HIGH on pin J2)
## -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports reset]

## -----------------------------------------------------------------------------
## 3. UART Serial TX (FPGA TX -> USB-UART RX on PC: Pin U11)
## -----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN U11 IOSTANDARD LVCMOS33} [get_ports uart_tx]

## -----------------------------------------------------------------------------
## 4. Diagnostic LEDs (led[0..3] and trap)
## -----------------------------------------------------------------------------
## led[0]: Clock Heartbeat (blinks at ~1.5 Hz when 100 MHz clock is alive)
set_property -dict {PACKAGE_PIN G1 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
## led[1]: CPU running indicator (HIGH when reset released)
set_property -dict {PACKAGE_PIN G2 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
## led[2]: UART TX line activity
set_property -dict {PACKAGE_PIN F1 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
## led[3]: CPU Trap indicator
set_property -dict {PACKAGE_PIN F2 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

## Dedicated trap port (mapped to LED 4 on pin E1)
set_property -dict {PACKAGE_PIN E1 IOSTANDARD LVCMOS33} [get_ports trap]

## -----------------------------------------------------------------------------
## 5. Spartan-7 Configuration & Flash Settings
## -----------------------------------------------------------------------------
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
