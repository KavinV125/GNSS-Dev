# PicoRV32 RISC-V SoC: u-blox ZED-F9P High-Precision GNSS Positioning Engine

An end-to-end, bare-metal **Hardware-Software Co-Design** System-on-Chip (SoC) combining a 32-bit RISC-V microprocessor (`PicoRV32`), custom hardware memory and bus controllers, a multi-channel autonomous UART GNSS telemetry subsystem, and bare-metal C firmware implemented on a **Real Digital Boolean Board (AMD/Xilinx Spartan-7 XC7S50)**.

Streaming live, multi-constellation satellite navigation data (GPS, GLONASS, Galileo, BeiDou) directly to host terminals at 115,200 baud with zero character loss.

---

## Table of Contents
1. [Project Overview & Key Highlights](#1-project-overview--key-highlights)
2. [Complete Flow: The VLSI / FPGA Hardware Engineer](#2-complete-flow-the-vlsi--fpga-hardware-engineer)
3. [Complete Flow: The Embedded Systems Engineer](#3-complete-flow-the-embedded-systems-engineer)
4. [Hardware-Software Co-Design Contract (MMIO Register Map)](#4-hardware-software-co-design-contract-mmio-register-map)
5. [Hardware Pinout & Wiring Specifications](#5-hardware-pinout--wiring-specifications)
6. [Live Telemetry Verification (Real On-Air GNSS Fix)](#6-live-telemetry-verification-real-on-air-gnss-fix)
7. [Repository File Inventory](#7-repository-file-inventory)
8. [Quick-Start & Build Guide](#8-quick-start--build-guide)

---

## 1. Project Overview & Key Highlights

Rather than relying on fixed off-the-shelf microcontrollers, this project builds the computing platform from the silicon level up:
- **Processor:** PicoRV32 32-bit RISC-V core (`RV32I` integer base ISA) running at **100 MHz**.
- **Memory:** 64 KB unified Block RAM (`BRAM`) for instructions, static data, heap, and descending stack.
- **GNSS Subsystem:** Custom synthesizable UART RX/TX physical layers with an autonomous 1024-byte First-Word-Fall-Through (`FWFT`) stream FIFO.
- **Multi-Header Auto-Detection:** Simultaneous listening on primary header (`C14/C13`) and Pmod JA (`V15/U16`) with internal pull-ups and anti-loopback filtering.
- **Hardware Transparent Bridge:** Zero-latency streaming from the GNSS FIFO directly to host PC UART (`PuTTY` @ 115,200 baud) with hardware CPU backpressure.
- **Live Performance:** Real-time lock and decoding of u-blox ZED-F9P multi-constellation signals tracking 12+ satellites across GPS, GLONASS, Galileo, and BeiDou.

---

## 2. Complete Flow: The VLSI / FPGA Hardware Engineer

The **VLSI / FPGA Engineer** owns digital architecture design, Verilog RTL implementation, memory subsystem inference, bus interconnect arbitrations, physical and timing constraints, testbench verification, and FPGA physical implementation (synthesis, placement, routing, and bitstream generation).

```
   ┌────────────────────────────────────────────────────────────────────────┐
   │                  VLSI / FPGA HARDWARE ENGINEERING FLOW                 │
   └────────────────────────────────────────────────────────────────────────┘
       │
       ▼
 1. Specification & Architecture
    ├── Select core ISA: PicoRV32 (RV32I, 32 registers, 100 MHz)
    ├── Define bus protocol: Synchronous 32-bit native memory bus
    └── Determine peripheral addresses: BRAM (0x00000000) & GNSS (0x02000000)
       │
       ▼
 2. RTL Implementation (Verilog / SystemVerilog)
    ├── Core CPU Integration      -> rtl/picorv32.v
    ├── Dual-Port 64 KB BRAM      -> rtl/bram.v (byte strobes, RAMB36/18 primitives)
    ├── UART RX & TX PHYs         -> rtl/gnss_uart_rx.v, rtl/uart_tx.v
    ├── 1024-Byte FWFT Stream FIFO-> rtl/gnss_rx_fifo.v
    ├── Collision-Free Bridge     -> rtl/gnss_bridge.v
    ├── MMIO Register Controller  -> rtl/gnss_regs.v
    ├── Top Interconnect          -> rtl/soc.v
    └── FPGA Top-Level Wrapper    -> rtl/picorv32_top.v (reset synchronizer, LEDs)
       │
       ▼
 3. Physical & Timing Constraints (XDC)
    ├── Master clock definition   -> 100 MHz oscillator (F14) : 10.000 ns period
    ├── I/O Pin mapping           -> Host UART (U11), Reset (J2), Diagnostic LEDs
    ├── GNSS Pin mapping          -> Primary (C14/C13) & Pmod JA (V15/U16)
    └── Pull-up configuration     -> PULLTYPE PULLUP on floating serial inputs
       │
       ▼
 4. Simulation & Verification (Testbenches)
    ├── Component-level tests     -> tb_gnss_uart_rx.v, tb_gnss_fifo.v, tb_gnss_bridge.v
    ├── System-level SoC test     -> tb_soc.v (Icarus Verilog + VVP + GTKWave)
    └── Bus handshake verification-> Single-wait-state BRAM & stall behavior
       │
       ▼
 5. Synthesis, Place & Route, Timing Closure (Vivado EDA)
    ├── RTL Elaboration & Synthesis
    ├── Logic Optimization & Placement
    ├── Static Timing Analysis (STA) -> WNS > 0 ns, TNS = 0.000 ns (Setup/Hold closed)
    └── Bitstream Generation        -> picorv32_top.bit
       │
       ▼
 6. Silicon Validation & In-System JTAG Debugging
    ├── Hardware Manager (hw_server) programming via scripts/flash_fpga.tcl
    └── Real-time logic verification on diagnostic LEDs (G1, G2, F1, F2)
```

### Key Hardware Engineering Deliverables
1. **Reset Conditioning:** 2-stage asynchronous-assert, synchronous-deassert flip-flop chain preventing metastability across the 100 MHz domain.
2. **True Dual-Port Byte-Wide BRAM:** Inferred as synchronous Xilinx Block RAMs responding with 1 wait state, supporting 8-bit, 16-bit, and 32-bit aligned/unaligned writes via `mem_wstrb[3:0]`.
3. **Hardware Backpressure & Bus Stalls:** If software writes to the host transmitter while it is busy, the MMIO controller withholds `mem_ready`, pausing the CPU bus cycle without dropping characters or needing software wait loops.
4. **Dual-Header Active-Low Combiner:** Combines `C14` and `V15` into `gnss_rx_combined = gnss_rx & gnss_rx_pmod`. Since idle UART is 3.3V (`1`), either header can be plugged in without requiring manual jumper or switch reconfiguration.
5. **Zero-Echo Mute Logic:** Mutes the GNSS RX FIFO input during transmission (`!gnss_tx_busy`) to eliminate local loopback of polling packets.

---

## 3. Complete Flow: The Embedded Systems Engineer

The **Embedded Systems Engineer** owns the software toolchain, assembly startup code, linker section placement, bare-metal C drivers, register abstraction layers, communications protocol parsing, and auto-baud rate acquisition algorithms.

```
   ┌────────────────────────────────────────────────────────────────────────┐
   │               EMBEDDED SYSTEMS SOFTWARE ENGINEERING FLOW               │
   └────────────────────────────────────────────────────────────────────────┘
       │
       ▼
 1. Toolchain & Runtime Environment Setup
    ├── Compiler: riscv32-unknown-elf-gcc (RV32I, ILP32 ABI, freestanding)
    ├── Compiler Flags: -march=rv32i -mabi=ilp32 -O2 -nostdlib -mno-relax
    └── Build Automation: scripts/build_firmware.py & firmware/Makefile
       │
       ▼
 2. Memory Section Layout (Linker Script)
    ├── firmware/linker.ld defines 64 KB memory window [0x00000000 - 0x00010000]
    ├── .text.start at 0x00000000 (Reset vector)
    ├── .text (C machine code) & .rodata (strings and constants)
    ├── .data & .bss (initialized and uninitialized global state)
    └── Stack pointer initialized to top of RAM (0x00010000) growing downwards
       │
       ▼
 3. Assembly Bootstrap (firmware/start.S)
    ├── Reset vector entry (_start)
    ├── Initialize stack pointer: lui sp, %hi(_stack_top)
    ├── Zero-initialize .bss section in word-aligned loop
    └── Jump to main(): jal ra, main
       │
       ▼
 4. Hardware Abstraction Layer (HAL & Drivers)
    ├── Memory-Mapped I/O pointers: #define GNSS_BASE 0x02000000
    ├── Software division routines: __udivsi3 and __umodsi3 (for RV32I)
    ├── Host serial driver: host_uart_puts(), host_uart_putint(), host_uart_puthex()
    └── Module serial driver: gnss_tx_send() (UBX binary and NMEA ASCII commands)
       │
       ▼
 5. Application Core Logic (firmware/main.c)
    ├── Print Interactive System Banner to PuTTY (COM23 @ 115200 baud)
    ├── Multi-Baud Auto-Scan Engine (38400 -> 9600 -> 115200 -> 57600)
    ├── Active Module Wake-Up (Sends UBX-MON-VER and $EIGPQ,RMC poll packets)
    ├── Live Status Loop: Outputs [Status | FIFO Count] every 250 ms
    ├── COM23 Pipeline Self-Test: Streams test NMEA blocks every 4 scan cycles
    └── Auto-Lock & Transparent Bridge Transition:
        └── On first valid byte ('$'), permanently locks baud and activates
            the zero-latency hardware bridge to stream live satellite telemetry
```

### Key Embedded Engineering Deliverables
1. **Freestanding Integer Math:** Implemented software restoring division routines (`__udivsi3` and `__umodsi3`) because the lightweight PicoRV32 configuration omits the hardware multiplier/divider (`RV32M`) to save FPGA LUTs.
2. **Volatile Register Semantics:** All MMIO pointers are declared `*(volatile unsigned int *)` to prevent the GCC optimizer from caching peripheral registers in CPU general-purpose registers.
3. **Resilient Auto-Baud Acquisition:** Cycles baud rates dynamically and reads the hardware FIFO status register to lock onto the GNSS module whether it defaults to factory 38,400 baud, standard 9,600 baud, or high-speed 115,200 baud.

---

## 4. Hardware-Software Co-Design Contract (MMIO Register Map)

The bridge between the VLSI Hardware and Embedded Software is the **Memory-Mapped I/O (MMIO)** contract at base address `0x0200_0000`:

| Offset | Register Name | Access | Bit Fields & Functional Description |
| :--- | :--- | :---: | :--- |
| `0x00` | `GNSS_RX_DATA` | **R / W** | **Read:** Pops and returns the 8-bit byte at the head of the GNSS RX FIFO.<br>**Write:** Transmits an 8-bit character directly to host PC UART (PuTTY). Stalls CPU if busy. |
| `0x04` | `GNSS_STATUS` | **R** | **Bit 0 (`STATUS_RX_VALID`):** FIFO contains $\ge 1$ byte.<br>**Bit 1 (`STATUS_FIFO_FULL`):** FIFO is full (1024 bytes).<br>**Bit 2 (`STATUS_FIFO_EMPTY`):** FIFO is empty.<br>**Bit 3 (`STATUS_FRAMING`):** Stop bit framing error detected.<br>**Bit 4 (`STATUS_OVERFLOW`):** FIFO write attempted while full.<br>**Bit 5 (`STATUS_GNSS_BUSY`):** GNSS TX PHY is currently shifting out a byte.<br>**Bit 6 (`STATUS_HOST_BUSY`):** Host UART TX PHY is transmitting to PuTTY.<br>**Bit 7 (`STATUS_BRIDGE_ON`):** Hardware transparent bridge is active. |
| `0x08` | `GNSS_CONTROL` | **R / W** | **Bit 0 (`bridge_en`):** `1` = Enable hardware FIFO-to-PuTTY bridge; `0` = CPU control.<br>**Bit 1 (`fifo_flush`):** Pulse `1` to instantly flush and clear the 1024-byte FIFO.<br>**Bit 2 (`loopback_en`):** `1` = Loopback GNSS TX into RX for self-test. |
| `0x0C` | `GNSS_BAUD_DIV` | **R / W** | 16-bit clock divider for GNSS UART ($Divider = \frac{100,000,000}{Baud}$).<br>• `2604` = 38,400 baud (u-blox default)<br>• `10416` = 9,600 baud<br>• `868` = 115,200 baud<br>• `1736` = 57,600 baud |
| `0x10` | `GNSS_TX_DATA` | **W** | Writing 8-bit byte transmits it out on GNSS TX to the u-blox module. Stalls CPU if busy. |
| `0x14` | `GNSS_FIFO_COUNT`| **R** | Returns number of bytes currently buffered in the GNSS RX FIFO (`0` to `1024`). |
| `0x18` | `GNSS_ERROR` | **R / W1C** | **Bit 0:** Framing error flag (Write `1` to clear).<br>**Bit 1:** FIFO overflow flag (Write `1` to clear). |

---

## 5. Hardware Pinout & Wiring Specifications

### Real Digital Boolean Board (XC7S50-CSGA324-1) Mapping

```
                                  TOP EDGE: PMOD JA
                     ┌────────────────────────────────────────┐
                     │ Pin 1 (V15) : GNSS RX (Alt)            │
                     │ Pin 2 (U16) : GNSS TX (Alt)            │
                     │ Pin 5 (GND) : System Ground            │
                     │ Pin 6 (VCC) : 3.3V Power Out           │
                     └────────────────────────────────────────┘

       PRIMARY HEADER PINS                       ONBOARD USB-UART BRIDGE
 ┌─────────────────────────────┐            ┌─────────────────────────────┐
 │ Pin C14 : GNSS RX (Primary) │            │ Pin U11 : Host UART TX      │
 │ Pin C13 : GNSS TX (Primary) │            │           (To PC PuTTY)     │
 └─────────────────────────────┘            └─────────────────────────────┘

       DIAGNOSTIC STATUS LEDS                       RESET CONTROL
 ┌─────────────────────────────┐            ┌─────────────────────────────┐
 │ LED 0 (G1) : 1.5 Hz Heartbeat│           │ Pin J2 : Active-HIGH Reset  │
 │ LED 1 (G2) : CPU Running    │            │          Pushbutton         │
 │ LED 2 (F1) : GNSS RX Pulse  │            └─────────────────────────────┘
 │ LED 3 (F2) : Bridge Active  │
 └─────────────────────────────┘
```

### Complete Pin Table

| Signal Name | FPGA Package Pin | Direction | I/O Standard | Description |
| :--- | :---: | :---: | :---: | :--- |
| `clk` | **F14** | Input | LVCMOS33 | 100 MHz primary crystal oscillator |
| `reset` | **J2** | Input | LVCMOS33 | Pushbutton reset (Active-HIGH) |
| `uart_tx` | **U11** | Output | LVCMOS33 | Host serial TX to PC USB-UART (`PuTTY` @ 115200) |
| `gnss_rx` | **C14** | Input | LVCMOS33 (PULLUP) | Primary GNSS Serial RX (Connect to ZED-F9P TX) |
| `gnss_tx` | **C13** | Output | LVCMOS33 | Primary GNSS Serial TX (Connect to ZED-F9P RX) |
| `gnss_rx_pmod`| **V15** | Input | LVCMOS33 (PULLUP) | Alternate GNSS RX on Pmod JA Pin 1 |
| `gnss_tx_pmod`| **U16** | Output | LVCMOS33 | Alternate GNSS TX on Pmod JA Pin 2 |
| `sw_bridge` | **V2** | Input | LVCMOS33 | Slide Switch SW0: Hardware Bridge Override |
| `led[0]` | **G1** | Output | LVCMOS33 | Heartbeat LED (blinks at ~1.5 Hz) |
| `led[1]` | **G2** | Output | LVCMOS33 | CPU Active LED (Solid ON when reset released) |
| `led[2]` | **F1** | Output | LVCMOS33 | GNSS RX Traffic Activity (pulses on received bytes) |
| `led[3]` | **F2** | Output | LVCMOS33 | Bridge Mode Status (ON when streaming to PuTTY) |
| `trap` | **E1** | Output | LVCMOS33 | CPU Trap Indicator (ON if processor enters fault) |

---

## 6. Live Telemetry Verification (Real On-Air GNSS Fix)

Below is an authentic sample of live telemetry acquired by this SoC from a physical u-blox ZED-F9P module and streamed to PuTTY:

```text
====================================================================
 PicoRV32 RISC-V SoC: u-blox ZED-F9P Real-Time GNSS Monitor
====================================================================
 FPGA Board : Real Digital Boolean Board (Spartan-7 XC7S50)
 System Clk : 100 MHz | Host PuTTY: 115200 Baud (Pin U11)
 Dual-Header Wiring Supported Simultaneously:
   Header 1 -> RX = Pin C14, TX = Pin C13
   Header 2 -> RX = Pin V15, TX = Pin U16 (Pmod JA Pin 1 & 2)
   Power    -> GND and 3.3V / 5V
====================================================================
[*] Initializing GNSS auto-baud detection & stream monitor...

[SCAN #1] Testing Baud: 38400 (div=2604) ... Listening on C14 & V15
   .. [Status: 0x00000001 | FIFO: 128 B] Waiting for data...

====================================================================
 [SUCCESS] LOCKED ONTO ZED-F9P @ 38400 BAUD!
 Streaming live raw NMEA sentences ($GNGGA, $GNRMC, etc.):
====================================================================

$GNGLL,1129.81566,N,07716.63495,E,110335.00,A,A*7F
$GNRMC,110336.00,A,1129.81570,N,07716.63493,E,0.056,,091026,,,A,V*11
$GNVTG,,T,,M,0.056,N,0.104,K,A*3B
$GNGGA,110336.00,1129.81570,N,07716.63493,E,1,12,1.38,253.7,M,-90.4,M,,*62
$GNGSA,A,3,07,30,27,09,08,,,,,,,,1.99,1.38,1.44,1*0B
$GNGSA,A,3,71,73,72,74,,,,,,,,,1.99,1.38,1.44,2*0C
$GNGSA,A,3,19,21,27,29,,,,,,,,,1.99,1.38,1.44,3*0C
$GNGSA,A,3,25,33,26,24,,,,,,,,,1.99,1.38,1.44,4*0B
$GPGSV,4,1,13,01,17,136,,02,21,111,,03,08,170,,04,54,147,,1*6A
$GPGSV,4,2,13,07,38,355,34,08,44,046,27,09,84,256,19,14,33,275,,1*6E
$GPGSV,4,3,13,17,23,204,,21,04,295,,22,21,256,,27,07,038,28,1*68
$GPGSV,4,4,13,30,18,322,33,1*5F
$GLGSV,3,1,09,70,27,171,,71,69,260,09,72,37,319,32,73,20,018,24,1*70
$GLGSV,3,2,09,74,28,326,22,75,10,276,,83,18,072,22,84,27,128,,1*7B
$GLGSV,3,3,09,85,12,170,,1*49
$GAGSV,3,1,09,07,38,135,,13,10,132,,19,33,330,23,21,58,320,33,7*76
$GAGSV,3,2,09,23,29,252,,26,10,180,,27,27,026,33,28,06,324,,7*75
$GAGSV,3,3,09,29,81,028,22,7*42
$GBGSV,4,1,13,01,18,096,,02,74,168,,06,05,162,,07,29,063,,1*77
$GBGSV,4,2,13,08,54,075,,09,19,179,,10,32,051,22,14,37,178,,1*7C
$GBGSV,4,3,13,21,16,163,,24,37,349,34,25,14,290,29,26,23,042,26,1*7D
$GBGSV,4,4,13,33,40,295,28,1*44
```

### Telemetry Analysis
- **Geographic Coordinates (`$GNGGA` / `$GNGLL`):**  
  `11°29.81570' N`, `077°16.63493' E` at an altitude of `253.7 meters` MSL (Tamil Nadu, India).
- **Satellite Constellations Actively Tracked:**
  - **`$GPGSV`:** GPS (USA) — 13 satellites in view, 5 tracked with high Carrier-to-Noise ratio ($C/N_0$ up to 34 dB-Hz).
  - **`$GLGSV`:** GLONASS (Russia) — 9 satellites in view, 4 tracked ($C/N_0$ up to 32 dB-Hz).
  - **`$GAGSV`:** Galileo (Europe) — 9 satellites in view, 4 tracked ($C/N_0$ up to 34 dB-Hz).
  - **`$GBGSV`:** BeiDou (China) — 13 satellites in view, 5 tracked ($C/N_0$ up to 34 dB-Hz).
- **Navigation Quality:** 3D Fix (`Fix Quality = 1`, `Satellites Used = 12`, `HDOP = 1.38`).

---

## 7. Repository File Inventory

```
d:\makeathon\
├── rtl\                              # Synthesizable Verilog Hardware Source
│   ├── picorv32_top.v                # Top-level FPGA module, clock/reset, pin bindings
│   ├── soc.v                         # System-on-Chip interconnect, bus decoder & arbiter
│   ├── picorv32.v                    # Claire Wolf's RV32I RISC-V processor core
│   ├── bram.v                        # 64 KB Block RAM with 4-lane byte-write strobes
│   ├── gnss_top.v                    # Complete GNSS subsystem top container
│   ├── gnss_uart_rx.v                # Center-sampling UART receiver with framing check
│   ├── gnss_uart_tx.v                # Command transmitter to u-blox module
│   ├── gnss_rx_fifo.v                # 1024-byte First-Word-Fall-Through (FWFT) FIFO
│   ├── gnss_bridge.v                 # Collision-free transparent bridge to Host UART
│   ├── gnss_regs.v                   # Memory-mapped peripheral registers (0x02000000)
│   ├── ubx_tx.v                      # Hardware UBX binary packet generator
│   ├── simple_uart.v                 # Legacy MMIO wrapper with hardware CPU backpressure
│   └── uart_tx.v                     # 115,200 baud host transmitter PHY (to PC PuTTY)
│
├── firmware\                         # Bare-Metal C & Assembly Software
│   ├── start.S                       # Assembly startup bootstrap (stack setup, BSS clear)
│   ├── main.c                        # C application (auto-baud scan, polls, bridge control)
│   ├── linker.ld                     # Linker script targeting 64 KB BRAM window
│   ├── Makefile                      # Cross-compilation makefile (RV32I)
│   └── bin_to_mem.py                 # Binary to 32-bit hex word converter
│
├── constraints\                      # FPGA Timing & Physical Constraints
│   └── picorv32_uart.xdc             # Pin mapping, 100 MHz clock period, pull-ups
│
├── simulation\                       # Verification Testbenches
│   ├── tb_soc.v                      # Full SoC simulation with behavioral UART monitor
│   ├── tb_gnss_bridge.v              # Transparent bridge arbitration testbench
│   ├── tb_gnss_fifo.v                # 1024-byte FIFO overflow & FWFT timing testbench
│   └── tb_gnss_uart_rx.v             # Center-sampling receiver testbench with noise injection
│
├── scripts\                          # Build & Automation Tooling
│   ├── build_firmware.py             # Compiles C firmware and synchronizes program.hex
│   ├── run_vivado_build.tcl          # Non-interactive Vivado batch synthesis & routing script
│   ├── flash_fpga.tcl                # Hardware Server JTAG FPGA programming script
│   └── monitor_uart.py               # Host-side Python serial console logger
│
├── build_and_flash.bat               # All-in-one automation script (Sim, Build, Flash)
└── README.md                         # Complete project documentation
```

---

## 8. Quick-Start & Build Guide

### Prerequisites
- **FPGA Toolchain:** AMD/Xilinx Vivado (2020.1 to 2025.1+)
- **Software Toolchain:** `riscv32-unknown-elf-gcc` (or automatic fallback to embedded toolchain)
- **Serial Terminal:** PuTTY or Python `pyserial` on Windows
- **Hardware:** Real Digital Boolean Board (`XC7S50CSGA324-1`), micro-USB cable, u-blox ZED-F9P module

### 1. Compile Firmware, Build Bitstream & Program FPGA (One Command)
Run the root automation script from PowerShell or Command Prompt:
```cmd
build_and_flash.bat flash
```
This batch flow executes:
1. `scripts/build_firmware.py`: Compiles `start.S` and `main.c`, generating `program.hex` and `program.mem`.
2. `Vivado batch mode`: Synthesizes, places, routes, closes timing, and emits `picorv32_top.bit`.
3. `JTAG programmer`: Connects to `localhost:3121` and flashes the Spartan-7 FPGA.

### 2. Run RTL Simulation (No FPGA Required)
To verify CPU execution and UART transmission using Icarus Verilog:
```cmd
build_and_flash.bat sim
```

### 3. Connect to the Live Serial Stream
1. Open **PuTTY**.
2. Select **Serial** connection type.
3. Configure settings:
   - **Serial line:** `COM23` (or your board's COM port from Device Manager)
   - **Speed (Baud):** `115200`
   - **Data bits:** `8` | **Stop bits:** `1` | **Parity:** `None` | **Flow control:** `None`
4. Click **Open**.
5. Press Pushbutton **`J2`** on the board to reset and observe the live startup banner and telemetry stream!
