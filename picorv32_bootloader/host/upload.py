#!/usr/bin/env python3
# Uploads a compiled PicoRV32 application (app.bin) to the resident
# bootloader over a serial port -- the PicoRV32 equivalent of clicking
# "Upload" in the Arduino IDE.
#
# Usage:
#   py upload.py COM14 ..\app\app.bin
#
# Protocol expected by bootloader/main.c:
#   1. Send a 4-byte little-endian length header.
#   2. Send that many raw bytes (the application image).
#   3. Wait for a single 'K' acknowledgement byte back from the board.

import sys
import struct
import time
import serial

def main():
    if len(sys.argv) != 3:
        print("Usage: py upload.py <COM_PORT> <path_to_app.bin>")
        sys.exit(1)

    port = sys.argv[1]
    bin_path = sys.argv[2]

    with open(bin_path, "rb") as f:
        data = f.read()

    print(f"App image: {bin_path} ({len(data)} bytes)")

    s = serial.Serial(port, 115200, timeout=2, rtscts=False, dsrdtr=False)
    s.dtr = False
    s.rts = False
    time.sleep(0.2)   # let the port settle

    header = struct.pack("<I", len(data))
    print("Sending length header...")
    s.write(header)
    s.flush()

    print("Sending application bytes...")
    s.write(data)
    s.flush()

    print("Waiting for acknowledgement...")
    ack = s.read(1)
    if ack == b"K":
        print("Upload confirmed -- application should now be running.")
    else:
        print(f"No/unexpected ack received: {ack!r}")
        print("The board may not have been reset just before running this "
              "script, or COM port/baud may be wrong.")

    s.close()

if __name__ == "__main__":
    main()
