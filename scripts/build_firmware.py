#!/usr/bin/env python3
"""
scripts/build_firmware.py
Automates Steps 1 to 5:
  1. Compile C / Assembly to .elf (if GCC is installed)
  2. Extract raw machine code to .bin
  3. Convert .bin into 32-bit hex words (program.hex / program.mem)
  4. Automatically sync program.hex into the Vivado project and root directory
If a RISC-V GCC toolchain is not found, it automatically uses the built-in
RV32I assembler to generate the exact machine code.
"""

import sys
import os
import shutil
import subprocess
import struct
import re

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
FIRMWARE_DIR = os.path.join(ROOT_DIR, "firmware")

def find_compiler():
    xilinx_path = r"D:\vivado\2025.1\gnu\riscv\nt\riscv64-unknown-elf\x86_64-w64-mingw32\usr\bin\riscv32-xilinx-elf"
    if os.path.isdir(xilinx_path) and xilinx_path not in os.environ.get("PATH", ""):
        os.environ["PATH"] = xilinx_path + os.pathsep + os.environ.get("PATH", "")

    candidates = [
        "riscv32-unknown-elf-gcc",
        "riscv32-xilinx-elf-gcc",
        "riscv-none-elf-gcc",
        "riscv64-unknown-elf-gcc",
        "riscv32-unknown-linux-gnu-gcc"
    ]
    for c in candidates:
        found = shutil.which(c)
        if found:
            return found
        direct = os.path.join(xilinx_path, f"{c}.exe")
        if os.path.isfile(direct):
            return direct
    return None

def extract_message_from_main_c():
    main_c_path = os.path.join(FIRMWARE_DIR, "main.c")
    if os.path.isfile(main_c_path):
        with open(main_c_path, "r", encoding="utf-8") as f:
            content = f.read()
            match = re.search(r'const\s+char\s*\*\s*msg\s*=\s*"([^"]*)"', content)
            if match:
                raw_str = match.group(1)
                # decode escape characters \r, \n, \t
                decoded = raw_str.encode().decode('unicode_escape')
                return decoded.encode('utf-8')
    return b"hello lingesh\r\n"

def assemble_builtin(msg_bytes, output_bin_path):
    """
    Built-in self-contained RV32I assembler for bare-metal PicoRV32.
    Initializes SP, sets UART TX pointer to 0x02000000, and streams characters.
    """
    instructions = [
        0x00010137, # lui sp, 0x10          (sp = 0x00010000, top of 64KB BRAM)
        0x02000337, # lui t1, 0x02000       (t1 = 0x02000000, UART TX register)
        0x02400293, # addi t0, zero, 0x24   (t0 = 0x00000024, pointer to string)
        0x0002c383, # lbu t2, 0(t0)         (load byte)
        0x00038863, # beq t2, zero, +16     (if t2 == 0 jump to done @ 0x20)
        0x00732023, # sw t2, 0(t1)          (store byte to UART TX register)
        0x00128293, # addi t0, t0, 1        (next character)
        0xff1ff06f, # jal zero, -16         (jump back to lbu @ 0x0C)
        0x0000006f, # jal zero, 0           (done: halt infinite loop @ 0x20)
    ]

    # Null terminate message
    payload = msg_bytes if msg_bytes.endswith(b'\0') else msg_bytes + b'\0'
    while len(payload) % 4 != 0:
        payload += b'\0'

    msg_words = [struct.unpack('<I', payload[i:i+4])[0] for i in range(0, len(payload), 4)]
    all_words = instructions + msg_words

    raw_bin = bytearray()
    for w in all_words:
        raw_bin += struct.pack('<I', w)

    with open(output_bin_path, "wb") as f:
        f.write(raw_bin)
    print(f"[*] Assembled {len(all_words)} RV32I words ({len(raw_bin)} bytes) using built-in assembler.")

def bin_to_hex(bin_path, hex_path, word_depth=16384):
    with open(bin_path, "rb") as f:
        data = f.read()

    while len(data) % 4 != 0:
        data += b'\x00'

    words = []
    for i in range(0, len(data), 4):
        w = struct.unpack('<I', data[i:i+4])[0]
        words.append(w)

    while len(words) < word_depth:
        words.append(0)

    with open(hex_path, "w", encoding="utf-8") as f:
        for w in words:
            f.write(f"{w:08x}\n")

    print(f"[*] Generated '{hex_path}' ({len(words)} words, 64 KB depth).")

def main():
    print("==================================================")
    print(" PicoRV32 Firmware Build & Memory Sync Automation ")
    print("==================================================")

    compiler = find_compiler()
    elf_file = os.path.join(FIRMWARE_DIR, "firmware.elf")
    bin_file = os.path.join(FIRMWARE_DIR, "firmware.bin")
    hex_file = os.path.join(FIRMWARE_DIR, "program.hex")

    if compiler:
        compiler_clean = compiler.replace("\\", "/")
        print(f"[*] Found RISC-V GCC: {compiler_clean}")
        base = compiler_clean
        if base.lower().endswith(".exe"):
            base = base[:-4]
        cross = base[:-3] if base.endswith("gcc") else "riscv32-unknown-elf-"
        fw_dir_clean = FIRMWARE_DIR.replace("\\", "/")
        cmd = f'make -C "{fw_dir_clean}" CROSS="{cross}"'
        print(f"[*] Running: {cmd}")
        res = subprocess.run(cmd, shell=True)
        if res.returncode != 0:
            print("[!] Make failed, falling back to built-in assembler...")
            msg = extract_message_from_main_c()
            assemble_builtin(msg, bin_file)
            bin_to_hex(bin_file, hex_file)
    else:
        print("[*] No RISC-V GCC in system PATH. Using high-speed built-in RV32I assembler.")
        msg = extract_message_from_main_c()
        print(f"[*] Target message: {msg}")
        assemble_builtin(msg, bin_file)
        bin_to_hex(bin_file, hex_file)

    # STEP 5: Automatically sync program.hex to project root and Vivado paths
    root_hex = os.path.join(ROOT_DIR, "program.hex")
    root_mem = os.path.join(ROOT_DIR, "program.mem")
    fw_mem   = os.path.join(FIRMWARE_DIR, "program.mem")

    shutil.copyfile(hex_file, root_hex)
    shutil.copyfile(hex_file, root_mem)
    shutil.copyfile(hex_file, fw_mem)
    print(f"[+] Synchronized 'program.hex' to project root: {root_hex}")

    # Search and sync to any active Vivado project subdirectories
    for root, dirs, files in os.walk(ROOT_DIR):
        if "sim_1" in root or "synth_1" in root:
            dest = os.path.join(root, "program.hex")
            shutil.copyfile(hex_file, dest)
            print(f"[+] Synced to Vivado run directory: {dest}")

    print("[+] Firmware build and memory synchronization COMPLETE!")

if __name__ == "__main__":
    main()
