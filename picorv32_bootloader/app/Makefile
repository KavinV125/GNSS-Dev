TOOLCHAIN_PREFIX = riscv-none-elf-

CFLAGS  = -march=rv32i -mabi=ilp32 -mno-relax -O2 -ffreestanding -Wall
LDFLAGS = -T sections.ld -nostdlib -Wl,--no-relax

all: app.bin

app.elf: start.s main.c sections.ld
	$(TOOLCHAIN_PREFIX)gcc $(CFLAGS) $(LDFLAGS) -o app.elf start.s main.c

app.bin: app.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary app.elf app.bin

clean:
	rm -f app.elf app.bin

.PHONY: all clean
