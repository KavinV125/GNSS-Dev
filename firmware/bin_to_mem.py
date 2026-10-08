#!/usr/bin/env python3
"""
bin_to_mem.py - Converts a raw RISC-V binary (.bin) into a Verilog/Vivado hex memory file (.hex / .mem)
for $readmemh initialization of Block RAM.

Handles little-endian word formatting and pads remaining depth with 00000000.
"""

import sys
import os
import shutil
import struct

def convert_bin_to_mem(bin_path, hex_path, word_depth=16384):
    if not os.path.isfile(bin_path):
        print(f"Error: Input binary '{bin_path}' not found.")
        sys.exit(1)

    with open(bin_path, "rb") as f:
        bin_data = f.read()

    # Pad binary data to a multiple of 4 bytes (32-bit word alignment)
    remainder = len(bin_data) % 4
    if remainder != 0:
        bin_data += b"\x00" * (4 - remainder)

    words = []
    # Read 32-bit words in little-endian order
    for i in range(0, len(bin_data), 4):
        word = struct.unpack("<I", bin_data[i:i+4])[0]
        words.append(word)

    actual_words = len(words)
    if actual_words > word_depth:
        print(f"Warning: Binary size ({actual_words} words) exceeds BRAM depth ({word_depth} words)!")

    # Pad with zeros up to the requested word depth
    while len(words) < word_depth:
        words.append(0)

    # Write one 8-digit hexadecimal word per line
    with open(hex_path, "w", encoding="utf-8") as f:
        for word in words:
            f.write(f"{word:08x}\n")

    print(f"Successfully converted '{bin_path}' -> '{hex_path}':")
    print(f"  Program payload: {actual_words} words ({actual_words * 4} bytes)")
    print(f"  Total BRAM depth: {word_depth} words ({word_depth * 4} bytes)")

    # Automatically synchronize to project root if building inside firmware/
    proj_root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(hex_path)), ".."))
    if os.path.isdir(os.path.join(proj_root, "rtl")):
        root_hex = os.path.join(proj_root, "program.hex")
        try:
            shutil.copyfile(hex_path, root_hex)
            print(f"[+] Synchronized '{os.path.basename(hex_path)}' to project root: {root_hex}")
        except Exception as e:
            print(f"[*] Root sync notice: {e}")

def main():
    if len(sys.argv) < 3:
        print("Usage: python bin_to_mem.py <input.bin> <output.hex> [word_depth]")
        print("Example: python bin_to_mem.py firmware.bin program.hex 16384")
        sys.exit(1)

    bin_file = sys.argv[1]
    hex_file = sys.argv[2]
    depth = int(sys.argv[3]) if len(sys.argv) > 3 else 16384

    convert_bin_to_mem(bin_file, hex_file, depth)

if __name__ == "__main__":
    main()
