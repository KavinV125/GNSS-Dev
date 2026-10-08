# Makefile for PicoRV32 Minimal SoC Firmware

CROSS   ?= $(shell python -c "import shutil, os; candidates = ['riscv32-unknown-elf-', 'riscv32-xilinx-elf-', 'riscv-none-elf-', 'D:/vivado/2025.1/gnu/riscv/nt/riscv64-unknown-elf/x86_64-w64-mingw32/usr/bin/riscv32-xilinx-elf/riscv32-unknown-elf-']; print(next((c for c in candidates if shutil.which(c+'gcc') or os.path.isfile(c+'gcc.exe')), 'riscv32-unknown-elf-'), end='')")
CROSS   := $(subst \,/,$(CROSS))
CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
SIZE    := $(CROSS)size
PYTHON  := python

# Architecture: rv32i (no multipliers, no compressed instructions), ABI: ilp32
CFLAGS  := -march=rv32i -mabi=ilp32 -O2 -Wall -Wextra -ffreestanding -nostdlib -mno-relax
LDFLAGS := -T linker.ld -nostdlib -Wl,--build-id=none -Wl,--no-relax

# BRAM memory depth in 32-bit words (16384 words = 64 KB)
BRAM_WORDS ?= 16384

TARGET_ELF := firmware.elf
TARGET_BIN := firmware.bin
TARGET_HEX := program.hex
TARGET_DIS := firmware.dis

.PHONY: all clean disasm

all: $(TARGET_HEX) $(TARGET_DIS)

$(TARGET_ELF): start.S main.c linker.ld
	$(CC) $(CFLAGS) $(LDFLAGS) start.S main.c -o $@
	$(SIZE) $@

$(TARGET_BIN): $(TARGET_ELF)
	$(OBJCOPY) -O binary $< $@

$(TARGET_HEX): $(TARGET_BIN) bin_to_mem.py
	$(PYTHON) bin_to_mem.py $(TARGET_BIN) $(TARGET_HEX) $(BRAM_WORDS)
	$(PYTHON) -c "import shutil; shutil.copyfile('$(TARGET_HEX)', 'program.mem')"

$(TARGET_DIS): $(TARGET_ELF)
	$(OBJDUMP) -d -S $< > $@

clean:
	@$(PYTHON) -c "import os, glob; [os.remove(f) for pat in ['*.o', '$(TARGET_ELF)', '$(TARGET_BIN)', '$(TARGET_HEX)', 'program.mem', '$(TARGET_DIS)'] for f in glob.glob(pat) if os.path.isfile(f)]; print('Cleaned build artifacts.')"
