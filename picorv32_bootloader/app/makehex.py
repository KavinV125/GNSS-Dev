#!/usr/bin/env python3
# Converts a raw binary image into a $readmemh-compatible hex file: one
# 32-bit little-endian word per line, padded with zero words to the
# requested size. Used only for the boot ROM (the app is sent as a raw
# .bin over UART instead -- see app/Makefile).
#
# Usage: python3 makehex.py bootloader.bin 512 > bootloader.hex

import sys

with open(sys.argv[1], "rb") as f:
    data = f.read()

words = int(sys.argv[2])

for i in range(words):
    off = i * 4
    chunk = data[off:off + 4]
    chunk = chunk + b"\x00" * (4 - len(chunk))
    val = chunk[0] | (chunk[1] << 8) | (chunk[2] << 16) | (chunk[3] << 24)
    print("%08x" % val)
