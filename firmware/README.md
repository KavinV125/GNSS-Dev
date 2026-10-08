# PicoRV32 Firmware Guide

This directory contains the bare-metal C and assembly firmware for the minimal PicoRV32 RISC-V SoC.

---

## 1. Directory Contents

- `start.S`: Bare-metal assembly startup code (initializes stack pointer, clears BSS, and jumps to `main()`).
- `main.c`: C firmware that writes the characters of `"hello lingesh\r\n"` to the memory-mapped UART register at `0x02000000`.
- `linker.ld`: Linker script configuring the 64 KB Block RAM origin (`0x00000000`) and stack boundaries.
- `bin_to_mem.py`: Python script converting the flat raw binary (`firmware.bin`) into a 32-bit hexadecimal word-per-line file (`program.hex`) for Verilog `$readmemh` and Vivado BRAM initialization.
- `Makefile`: Build automation file to assemble, compile, link, and format the firmware.
- `program.hex`: Pre-generated 64 KB memory initialization file ready to run directly out of the box.

---

## 2. Prerequisites (Toolchain Options)

To compile the C source files into RISC-V binaries, a 32-bit RISC-V bare-metal GCC toolchain is required.

### Recommended Toolchains:
1. **Windows (Pre-built binary)**:
   - Download the **xPack GNU RISC-V Embedded GCC**:
     [https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases)
   - Extract the folder (e.g. `C:\xpack-riscv-gcc\bin`) and add it to your Windows `PATH`.
   - The compiler will be available as `riscv-none-elf-gcc`.

2. **Linux / WSL (Ubuntu/Debian)**:
   ```bash
   sudo apt-get update
   sudo apt-get install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
   ```
   *(Note: The 64-bit GCC also supports `-march=rv32i -mabi=ilp32`)*

3. **MSYS2 (Windows)**:
   ```bash
   pacman -S mingw-w64-x86_64-riscv64-unknown-elf-gcc
   ```

---

## 3. Building the Firmware

### Step 1: Run the Makefile
From inside the `firmware/` directory:

```bash
# If using riscv32-unknown-elf-gcc:
make

# If using xPack toolchain (riscv-none-elf-gcc):
make CROSS=riscv-none-elf-

# If using Ubuntu/Debian multilib toolchain:
make CROSS=riscv64-unknown-elf-
```

This performs the following steps automatically:
1. Compiles `start.S` and `main.c` targeting RV32I (`-march=rv32i -mabi=ilp32 -O2 -nostdlib`).
2. Links with `linker.ld` to produce `firmware.elf`.
3. Runs `objcopy -O binary` to produce `firmware.bin`.
4. Runs `python bin_to_mem.py firmware.bin program.hex 16384` to produce the Verilog `$readmemh` compatible file.
5. Generates the assembly disassembly file `firmware.dis` for inspection.

---

## 4. Converting Binary to Hex Manually

If you built `firmware.bin` through another IDE or tool, you can convert it using `bin_to_mem.py`:

```bash
python bin_to_mem.py firmware.bin program.hex 16384
```

- **Parameter 1**: Input binary file (`firmware.bin`).
- **Parameter 2**: Output hex file (`program.hex`).
- **Parameter 3**: Total word depth of the BRAM (16384 words = 64 KB). Any memory above the program size is padded with `00000000`.

---

## 5. Memory Layout

```
0x00000000 ┌────────────────────────────────────────┐
           │ .text (Instructions: start.S & main.c) │
           ├────────────────────────────────────────┤
           │ .rodata ("hello lingesh\r\n" string)   │
           ├────────────────────────────────────────┤
           │ .data & .bss (Global variables)        │
           ├────────────────────────────────────────┤
           │ Heap & free BRAM space                 │
           │                                        │
           │                  ▲                     │
           │                  │ (Stack grows DOWN)  │
0x00010000 └──────────────────┴─────────────────────┘ (Initial SP)
```
