#!/usr/bin/env python3
"""
scripts/monitor_uart.py
Simple serial terminal monitor to read and display output from COM22.
"""

import sys
import serial
import serial.tools.list_ports

def find_com_port(preferred="COM22"):
    ports = list(serial.tools.list_ports.comports())
    for p in ports:
        if p.device.upper() == preferred.upper():
            return p.device
    for p in ports:
        if "0403:6010" in p.hwid or "FTDI" in p.description.upper() or "USB SERIAL" in p.description.upper():
            return p.device
    return preferred

def main():
    port = sys.argv[1] if len(sys.argv) > 1 else find_com_port("COM22")
    baud = int(sys.argv[2]) if len(sys.argv) > 2 else 115200

    print("==================================================")
    print(f" PicoRV32 Serial Monitor: {port} @ {baud} Baud")
    print(" Press Ctrl+C to exit")
    print("==================================================")

    try:
        ser = serial.Serial(port, baud, timeout=0.1)
    except Exception as e:
        print(f"Error opening {port}: {e}")
        print("Note: If PuTTY or another terminal is open, close it first.")
        sys.exit(1)

    try:
        while True:
            data = ser.read(ser.in_waiting or 1)
            if data:
                sys.stdout.write(data.decode("utf-8", errors="replace"))
                sys.stdout.flush()
    except KeyboardInterrupt:
        print("\n\nMonitor terminated.")
    finally:
        ser.close()

if __name__ == "__main__":
    main()
