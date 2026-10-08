# PicoRV32 RISC-V SoC: Embedded Software Engineer's Manual

**Target Hardware:** PicoRV32 RV32I Processor on Xilinx Spartan-7 (`XC7S50CSGA324-1`)  
**Core Clock Frequency:** 100 MHz  
**Default UART Baud Rate:** 115,200 Baud (8-N-1)  
**System Memory:** 64 KB Unified SRAM (Instructions + Data + Stack)  

---

## 1. System Architecture & Memory Map

As an embedded software engineer, you interact with this SoC via **Memory-Mapped Input/Output (MMIO)** over a single 32-bit unified bus.

### 1.1 Memory Map

| Address Range | Size | Region Name | Access Mode | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x0000_0000` – `0x0000_FFFF` | 64 KB | **BRAM Memory** | R / W / X | Unified program code, constants, data, and stack |
| `0x0200_0000` | 4 Bytes | **UART Peripheral** | R / W | UART TX data register (write) and status register (read) |
| *All other addresses* | — | *Unmapped* | R / W | Returns `0x0000_0000` on read; writes ignored |

### 1.2 CPU Hardware Specifications
- **Instruction Set Architecture:** **RV32I** (Base 32-bit Integer RISC-V).
- **Endianness:** **Little-Endian** (least significant byte at lowest address).
- **Supported Instructions:** Standard integer arithmetic, logic, branch, jump, load, and store instructions.
- **Hardware Multiply / Divide:** **NOT present** (RV32M is disabled). Any multiplication (`*`) or division (`/`) must be performed using compiler software routines or bit shifts.
- **Compressed Instructions:** **NOT present** (RV32C is disabled). All instructions are exactly 32 bits (4 bytes) wide.
- **Hardware Timers / Counters:** RV32 `rdcycle` instruction is enabled (readable via `rdcycle` CSR or inline assembly).

---

## 2. Memory-Mapped Peripheral Programming Model

### 2.1 UART TX Peripheral Register (`0x0200_0000`)

The UART peripheral is mapped directly at address `0x0200_0000`.

#### A. Write Operation (Transmit Byte)
Writing to address `0x0200_0000` transmits a byte over the serial line:

```c
#define UART_REG (*(volatile unsigned int *)0x02000000)

void uart_putc(char c) {
    UART_REG = (unsigned int)c;
}
```

> **Hardware Flow Control (Zero Lost Characters):**  
> If the UART transmitter is currently busy transmitting a previous character, the hardware bus controller **automatically stalls the CPU bus cycle** until the transmitter becomes free.  
> You do **not** need a software delay loop. The CPU will automatically pace itself to the 115,200 baud transmission rate.

#### B. Read Operation (Status Register)
Reading from address `0x0200_0000` returns the peripheral status:
- **Bit 0 (`tx_busy`):** `1` if transmitter is active; `0` if idle.
- **Bits 31:1:** Reserved (`0`).

```c
int uart_is_busy(void) {
    return (UART_REG & 0x01);
}
```

### 2.2 MMIO Programming Rules for C Developers
1. **Always use `volatile`:** The compiler will optimize away repeated writes or reads to the same address if pointers are not marked `volatile`.
2. **Access Alignment:** The UART register is a 32-bit word-aligned address (`0x02000000`). While the hardware accepts byte stores (`sb`), standard 32-bit unsigned integer writes (`sw`) are recommended.

---

## 3. The Bare-Metal Startup Sequence (From Reset to `main()`)

When the FPGA powers on or the reset button (`C18`) is released, the PicoRV32 processor vectors to address `0x0000_0000`.

Because there is no operating system, BIOS, or bootloader, the assembly startup code in [`firmware/start.S`](file:///d:/makeathon/firmware/start.S) sets up the C runtime environment:

```assembly
.section .text.start
.global _start
.type _start, @function

_start:
    /* 1. Initialize Stack Pointer to top of BRAM (0x00010000) */
    la sp, _stack_top

    /* 2. Clear uninitialized global variables (.bss section) */
    la t0, _bss_start
    la t1, _bss_end
zero_bss_loop:
    bgeu t0, t1, zero_bss_done
    sw zero, 0(t0)
    addi t0, t0, 4
    j zero_bss_loop
zero_bss_done:

    /* 3. Call C application entry point */
    call main

    /* 4. Catch unexpected return from main() */
hang:
    j hang

.size _start, . - _start
```

### Critical Setup Responsibilities Handled by `start.S`:
1. **Stack Pointer Setup:** Initializes register `sp` (`x2`) to `0x0001_0000`. In RISC-V, the stack grows downwards towards `0x0000_0000`.
2. **BSS Segment Clearing:** Global and `static` uninitialized C variables are mandated by the C standard to start at `0`. `start.S` zeroes this memory before `main()` starts.
3. **Branch to `main()`:** Jumps into standard C code. If `main()` exits, the CPU enters an infinite loop (`hang`) to prevent PC runaway.

---

## 4. Memory Layout & Linker Configuration (`linker.ld`)

The memory map is defined in [`firmware/linker.ld`](file:///d:/makeathon/firmware/linker.ld). The total available memory is 64 KB (65,536 bytes):

```
0x0000_0000 ┌──────────────────────────────────────────────┐
            │ .text.start (_start entry point)             │
            ├──────────────────────────────────────────────┤
            │ .text (Program code & C functions)           │
            ├──────────────────────────────────────────────┤
            │ .rodata (Constant strings, literals, tables) │
            ├──────────────────────────────────────────────┤
            │ .data (Initialized global/static variables)  │
            ├──────────────────────────────────────────────┤
            │ .bss (Zero-initialized global variables)     │
            ├──────────────────────────────────────────────┤
            │ Heap space (Dynamically allocated if used)   │
            │                                              │
            │                     ▲                        │
            │                     │ Stack grows DOWNWARD   │
0x0001_0000 └─────────────────────┴────────────────────────┘ (Initial SP: _stack_top)
```

### Embedded Memory Budget Rules:
- Your total code + data + stack must not exceed **64 KB**.
- For small firmware (like hello-world), total consumption is typically less than 500 bytes, leaving over 63 KB for stack operations.
- Avoid massive local stack buffers (e.g. `char buf[100000]`), as they will overflow the 64 KB boundary and corrupt code.

---

## 5. Toolchain Requirements & Compiler Flags

### 5.1 Compiler Suite
Use any bare-metal RISC-V GCC cross-compiler. The system is already pre-configured with the official Xilinx Vivado RISC-V Bare-Metal GCC Suite (v13.3.0):
- `riscv32-unknown-elf-gcc` (Aliased & in PATH)
- `riscv32-xilinx-elf-gcc` (Native binary at `D:\vivado\2025.1\gnu\riscv\nt\riscv64-unknown-elf\x86_64-w64-mingw32\usr\bin\riscv32-xilinx-elf`)
- `riscv-none-elf-gcc` (Aliased & in PATH)

The directory is permanently registered in your User `PATH`, so running `make` or calling `riscv32-unknown-elf-gcc` works immediately from any command prompt.

### 5.2 Mandatory Compiler Flags

```bash
riscv32-unknown-elf-gcc \
    -march=rv32i \
    -mabi=ilp32 \
    -O2 \
    -Wall -Wextra \
    -ffreestanding \
    -nostdlib \
    -mno-relax \
    -T linker.ld \
    start.S main.c -o firmware.elf
```

| Flag | Why it is mandatory |
| :--- | :--- |
| `-march=rv32i` | **CRITICAL:** Forces compiler to emit ONLY base integer instructions. Disallows hardware multipliers (`mul`), hardware divide (`div`), and compressed instructions (`c.addi`). |
| `-mabi=ilp32` | Standard 32-bit integer, long, pointer calling convention. |
| `-nostdlib` | Excludes standard OS C runtime libraries (since there is no Linux or Windows underlying kernel). |
| `-ffreestanding` | Informs compiler that standard library headers may not be present and `main()` does not take `argc`/`argv`. |
| `-mno-relax` | Prevents linker from assuming global pointer (`gp`) relaxation, avoiding unexpected address offsets. |

---

## 6. Daily Embedded Development Workflow

### Step 1: Write or Modify Your C Code
Open [`firmware/main.c`](file:///d:/makeathon/firmware/main.c) and implement your application logic.

### Step 2: Build the Firmware
Run the automated Python builder or `make`:

```cmd
python scripts\build_firmware.py
```
*(or `make -C firmware` if you have `riscv32-unknown-elf-gcc` installed)*

This automatically:
1. Compiles `start.S` and `main.c` $\to$ `firmware.elf`.
2. Converts ELF $\to$ flat binary `firmware.bin`.
3. Formats binary into 16,384 lines of 32-bit hex words $\to$ `program.hex`.
4. Copies `program.hex` into the project root and Vivado working folders.

### Step 3: Test Before Flashing (Behavioral Simulation)
You can verify your code's serial output on your computer in 1 second without touching the hardware:

```cmd
.\build_and_flash.bat sim
```

### Step 4: Flash to FPGA
Connect your board over USB and run:

```cmd
.\build_and_flash.bat flash
```

### Step 5: Monitor Output
Open **PuTTY** on the assigned Windows COM port:
- **Baud Rate:** `115200`
- **Data Bits:** `8`, **Stop Bits:** `1`, **Parity:** `None`, **Flow Control:** `None`
- Press the red **RESET** button (`C18`) on your board to restart firmware execution.

---

## 7. Embedded Driver Reference Implementations

Here are reusable drivers and utilities you can integrate into your firmware:

### 7.1 Complete Modular UART Driver (`uart.h` / `uart.c`)

#### `uart.h`
```c
#ifndef UART_H
#define UART_H

#define UART_BASE 0x02000000
#define UART_REG  (*(volatile unsigned int *)UART_BASE)

void uart_putc(char c);
void uart_puts(const char *s);
void uart_put_hex(unsigned int val);
void uart_put_dec(unsigned int val);

#endif
```

#### `uart.c`
```c
#include "uart.h"

void uart_putc(char c) {
    // Hardware automatically stalls CPU writes if UART is busy
    UART_REG = (unsigned int)c;
}

void uart_puts(const char *s) {
    while (*s) {
        if (*s == '\n') {
            uart_putc('\r'); // Auto-append carriage return for terminal emulators
        }
        uart_putc(*s++);
    }
}

void uart_put_hex(unsigned int val) {
    const char hex_chars[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 7; i >= 0; i--) {
        uart_putc(hex_chars[(val >> (i * 4)) & 0xF]);
    }
}

void uart_put_dec(unsigned int val) {
    char buf[12];
    int idx = 0;
    if (val == 0) {
        uart_putc('0');
        return;
    }
    while (val > 0) {
        buf[idx++] = (char)('0' + (val % 10));
        val /= 10;
    }
    while (idx > 0) {
        uart_putc(buf[--idx]);
    }
}
```

### 7.2 CPU Cycle Measurement (`rdcycle`)
Because the PicoRV32 has `ENABLE_COUNTERS = 1`, you can read the 64-bit cycle counter to measure exact execution time:

```c
static inline unsigned int get_cycles(void) {
    unsigned int cycles;
    __asm__ volatile("rdcycle %0" : "=r"(cycles));
    return cycles;
}

void delay_cycles(unsigned int count) {
    unsigned int start = get_cycles();
    while ((get_cycles() - start) < count);
}

void delay_ms(unsigned int ms) {
    // At 100 MHz, 1 ms = 100,000 clock cycles
    delay_cycles(ms * 100000);
}
```

---

## 8. Embedded Engineer Troubleshooting & Trap Handling

| Symptom | Cause | How to Diagnose & Fix |
| :--- | :--- | :--- |
| **User LED0 (`E18`) turns ON** | **CPU TRAP:** Illegal instruction or misaligned memory access occurred. | **Cause 1:** Compiled with `-march=rv32im` instead of `-march=rv32i` (CPU encountered hardware `mul`/`div`).<br>**Cause 2:** Function pointer called invalid memory address.<br>**Cause 3:** 32-bit load/store performed on address not divisible by 4. |
| **No serial output in PuTTY** | Board held in reset or wrong baud rate. | 1. Ensure `reset` button (`C18`) is not held down.<br>2. Confirm PuTTY baud rate is **115200**.<br>3. Confirm FPGA clock is 100 MHz. |
| **PuTTY shows garbled text** | Baud rate / frequency divider mismatch. | If running on a 50 MHz board, change `CLOCK_FREQ = 50000000` in `picorv32_top.v`. |
| **Global variables lose values** | `start.S` did not clear BSS or linker script overlap. | Ensure variables marked `static` or global reside in `.data` or `.bss`, and `_start` runs before `main()`. |
| **Firmware works in simulation but not on FPGA** | Uninitialized pointers or missing `$readmemh`. | Verify that `program.hex` is included in the Vivado project sources and matches the synthesized bitstream. |
