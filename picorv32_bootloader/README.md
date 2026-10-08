# picorv32_bootloader — Arduino-style UART bootloader for PicoRV32

Upload firmware over serial without re-running Vivado every time, the same
way you upload sketches to an Arduino — with one important difference
explained in "Known limitation" below.

## Folder layout

- `top.v` — PicoRV32 + boot ROM + application RAM + UART + LEDs
- `boolean_bootloader.xdc` — pin constraints (clk, btn_rst, led[15:0], UART)
- `build.tcl` — Vivado project/synthesis/bitstream script
- `bootloader/` — the resident bootloader firmware (baked into the bitstream)
- `app/` — your actual application firmware (sent over UART at runtime)
- `host/upload.py` — the "Upload" button, as a Python script

## You still need to add

Copy `picorv32.v` (from your downloaded YosysHQ/picorv32 repo) into this
top-level folder, next to `top.v`, before running `build.tcl`.

## Build order

### 1. Build the bootloader (WSL) — this gets baked into the bitstream
```
cd bootloader
make clean
make
```
This produces `bootloader/bootloader.hex`. Copy it into the top-level
folder (next to `top.v`) — `$readmemh("bootloader.hex", bootrom)` in
`top.v` expects it there.

### 2. Build the bitstream (Vivado)
In the Tcl Console:
```
cd {D:/RISCV_FPGA/picorv32_bootloader}
source build.tcl
```

### 3. Program the FPGA
Open Hardware Manager → Open Target → Auto Connect → Program Device,
using the `.bit` file the script printed.

At this point the 16 LEDs should show pattern `0x0001` (binary
`0000000000000001`) — the bootloader is running and waiting for an upload.
Nothing else happens until you send it something.

### 4. Build your application (WSL)
```
cd app
make clean
make
```
This produces `app/app.bin` — the LED-walk demo, by default.

### 5. Upload it (Windows, Python)
```
py host\upload.py COM14 app\app.bin
```
Use whatever COM port your board actually shows in Device Manager.

Watch the LEDs: they should jump to pattern `0x0003` briefly (receiving),
then `0xFFFF` (about to jump), then your application takes over and the
familiar LED-walk pattern begins.

### 6. Change the app and re-upload — no Vivado required
Edit `app/main.c`, `make` again, and re-run `upload.py`. This is the whole
point of adding the bootloader: steps 4-5 replace re-synthesizing.

## Known limitation: this is not exactly like Arduino

Arduino writes your sketch into **flash**, which is non-volatile — it
survives power-off and the chip runs your sketch again automatically on
every power-up, no re-upload needed.

This design's App RAM is **volatile FPGA block RAM**. Every time the FPGA
is reset or powered off, App RAM goes back to empty, and the bootloader
starts waiting for a fresh upload again — every single time. There is no
"remembers my last app" behavior here. Adding that would mean writing to
external SPI flash and teaching the bootloader to also read from there on
boot, which is a further project on top of this one.

## If something doesn't work

- **LEDs never leave `0x0001`**: the bootloader is waiting and nothing
  arrived. Check the COM port number, that `upload.py` actually ran
  without a Python error, and that TX/RX aren't swapped (V12/U11 in the
  `.xdc` should match your board's onboard USB-UART bridge, same as your
  NEORV32 setup used).
- **Ack byte never comes back / `upload.py` times out**: this usually means
  framing errors on receive — double-check `CLKS_PER_BIT` in `top.v`
  actually matches 115200 baud at your real clock frequency, and that nothing
  else is holding `btn_rst` high.
- **LEDs jump straight to `0xFFFF` but nothing runs afterward**: likely the
  application's linker script origin (`0x10000000`) doesn't match `APP_BASE`
  in `bootloader/main.c` — both must agree exactly.
