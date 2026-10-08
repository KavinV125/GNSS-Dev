@echo off
setlocal

REM ==============================================================================
REM build_and_flash.bat - All-in-One PicoRV32 Automation Script
REM
REM Modes:
REM   build_and_flash.bat            -> Build firmware & directly flash FPGA
REM   build_and_flash.bat flash      -> Build firmware & directly flash FPGA
REM   build_and_flash.bat noflash    -> Build firmware & bitstream only (DO NOT FLASH)
REM   build_and_flash.bat sim        -> Build firmware & run UART simulation
REM ==============================================================================

set "MODE=%~1"
if "%MODE%"=="" set "MODE=flash"

echo ==================================================
echo  PicoRV32 Automation Pipeline: MODE = %MODE%
echo ==================================================

REM --- STEP 1 to 5: Build firmware & sync program.hex ---
echo [1/3] Building firmware and generating program.hex...
python scripts\build_firmware.py
if errorlevel 1 (
    echo [ERROR] Firmware build failed!
    exit /b 1
)

REM --- SIMULATION MODE ---
if /I "%MODE%"=="sim" (
    echo [2/3] Compiling and running simulation with Icarus Verilog...
    iverilog -o sim.vvp -g2012 rtl\picorv32.v rtl\uart_tx.v rtl\simple_uart.v rtl\bram.v rtl\soc.v rtl\picorv32_top.v simulation\tb_soc.v
    if errorlevel 1 (
        echo [ERROR] iverilog compilation failed!
        exit /b 1
    )
    echo [3/3] Running simulation...
    vvp sim.vvp
    exit /b 0
)

REM --- LOCATE VIVADO ---
set "VIVADO_CMD=vivado"
where vivado >nul 2>nul
if errorlevel 1 goto :FIND_VIVADO
goto :VIVADO_FOUND

:FIND_VIVADO
if exist "D:\vivado\2025.1\Vivado\bin\vivado.bat" (
    set "VIVADO_CMD=D:\vivado\2025.1\Vivado\bin\vivado.bat"
    goto :VIVADO_FOUND
)
if exist "C:\Xilinx\Vivado\2025.1\bin\vivado.bat" (
    set "VIVADO_CMD=C:\Xilinx\Vivado\2025.1\bin\vivado.bat"
    goto :VIVADO_FOUND
)
echo [WARNING] Vivado not found in PATH or standard directories.
echo If you are running Vivado from the GUI, you can now generate bitstream manually.
exit /b 0

:VIVADO_FOUND
REM --- BITSTREAM GENERATION ---
if exist "picorv32_top.bit" goto :BITSTREAM_EXISTS

echo [2/3] Generating FPGA Bitstream via Vivado batch mode...
call "%VIVADO_CMD%" -mode batch -source scripts\run_vivado_build.tcl
if errorlevel 1 (
    echo [ERROR] Bitstream generation failed! Check vivado.log for details.
    exit /b 1
)
goto :CHECK_FLASH_MODE

:BITSTREAM_EXISTS
echo [2/3] Bitstream picorv32_top.bit already exists.

:CHECK_FLASH_MODE
if /I "%MODE%"=="noflash" (
    echo [3/3] PROVISION: noflash specified.
    echo [OK] Bitstream and memory files are ready on disk: picorv32_top.bit
    echo [OK] FPGA was NOT flashed directly as requested.
    exit /b 0
)

REM --- FLASH FPGA VIA JTAG ---
echo [3/3] Programming FPGA device over JTAG...
call "%VIVADO_CMD%" -mode batch -source scripts\flash_fpga.tcl
if errorlevel 1 (
    echo [ERROR] Flashing failed! Ensure FPGA board is powered on and USB cable is connected.
    exit /b 1
)

echo.
echo ==================================================
echo  DONE! Open PuTTY at 115200 Baud to see:
echo  hello lingesh
echo ==================================================
