# Bare-Metal Blink on Vicharak Shrike Lite (RP2040)

**Zero SDK. Zero libraries. Pure register-level C on the ARM Cortex-M0+.**

This project blinks an LED on the [Vicharak Shrike Lite](https://vicharak-in.github.io/shrike/) dev board using nothing but the ARM cross-compiler and raw memory-mapped I/O. Every byte in the final binary is hand-placed — no Pico SDK, no Arduino, no MicroPython, no HAL.

## Why?

Most RP2040 tutorials use the Pico SDK or MicroPython, which hides the actual hardware. This project strips away every abstraction layer to reveal what happens between **power-on** and **LED toggle** at the silicon level:

1. **The ROM bootloader** reads 256 bytes from flash, checks a CRC32
2. **Our boot2** configures QSPI flash for XIP (eXecute In Place)
3. **Our startup code** (crt0) sets the stack pointer, zeros `.bss`, copies `.data`, calls `main()`
4. **Our main()** un-resets the GPIO subsystem, routes a pin to the SIO block, and toggles it in a single CPU cycle

## Hardware

- **Board:** Vicharak Shrike Lite
- **MCU:** Raspberry Pi RP2040 (Dual-core ARM Cortex-M0+ @ 133MHz, 264KB SRAM)
- **FPGA:** Renesas ForgeFPGA SLG47910 (1,120 LUTs)
- **LED Pin:** GPIO 25 (change `LED_PIN` in `main.c` if your board differs)

## The RP2040 Memory Map

```
  Address         What
  ──────────────────────────────────────────────────
  0x00000000      Boot ROM (16KB, mask ROM)
  0x10000000      QSPI Flash (XIP) ← our code lives here
  0x20000000      SRAM (264KB) ← stack and variables
  0x4000C000      RESETS controller
  0x40014000      IO_BANK0 (GPIO function mux)
  0x4001C000      PADS_BANK0 (pad electrical config)
  0xD0000000      SIO (Single-cycle I/O) ← 1-cycle GPIO access
```

## Files

```
shrike-bare-metal/
├── rp2040.h           Register definitions (all from the official datasheet)
├── main.c             The program: un-reset → configure → blink
├── crt0.S             Startup: vector table + reset handler
├── boot2.S            256-byte second-stage bootloader (QSPI XIP config)
├── memmap.ld          Linker script (BOOT2 / FLASH / RAM layout)
├── Makefile           Build pipeline: assemble → link → CRC → UF2
├── pad_checksum.py    Pad boot2 to 252 bytes + append CRC32
├── elf2uf2.py         Convert raw binary to UF2 flash format
├── NOTES.md           First-principles engineering notes on boot chain, bus, and memory map
└── README.md          This file
```

## Build & Flash

### Prerequisites

```bash
# Arch Linux
sudo pacman -S arm-none-eabi-gcc arm-none-eabi-newlib python

# Ubuntu / Debian
sudo apt install gcc-arm-none-eabi libnewlib-arm-none-eabi python3
```

### Build

```bash
make
```

Output:
```
boot2: boot2_raw.bin -> boot2_padded.bin (256 bytes, CRC32=0xABCD1234)
--- Section sizes ---
   text    data     bss     dec     hex filename
    XXX       0       0     XXX     XXX blink.elf
UF2: blink.bin -> blink.uf2 (XXX bytes, X blocks)

========================================
  BUILD COMPLETE: blink.uf2
  Flash: hold BOOT + plug USB, then:
    cp blink.uf2 /media/$USER/RPI-RP2/
========================================
```

### Flash

1. **Hold the BOOT button** on your Shrike Lite
2. **Plug in USB-C** — the board mounts as a drive called `RPI-RP2`
3. Run:
   ```bash
   make flash
   # or manually:
   cp blink.uf2 /media/$USER/RPI-RP2/
   ```
4. The board auto-reboots and the LED starts blinking

### Debug / Inspect

```bash
make disasm    # Generate annotated disassembly listing
make size      # Show section size breakdown
```

## How It Works (The Three Registers)

To toggle an LED on the RP2040 from scratch, you talk to three hardware blocks:

### 1. RESETS (`0x4000C000`) — Wake up the GPIO

On power-up, the RP2040 holds almost all peripherals in reset to save power. You must clear bit 5 (`IO_BANK0`) and bit 8 (`PADS_BANK0`) and wait for `RESET_DONE` to confirm.

### 2. IO_BANK0 (`0x40014000`) — Route the pin

Each physical pin can be SPI, UART, I2C, PWM, or SIO. Writing `FUNCSEL=5` into `GPIO25_CTRL` connects the pin to the CPU's Single-cycle I/O block.

### 3. SIO (`0xD0000000`) — Toggle the pin

The SIO block provides atomic SET/CLR/XOR registers. Writing `(1<<25)` to `GPIO_OUT_XOR` toggles pin 25 in exactly **one CPU cycle** — no read-modify-write, fully interrupt-safe.

## Register Reference

| Address | Register | Purpose |
|---|---|---|
| `0x4000C000` | `RESETS_RESET` | Assert/deassert peripheral resets |
| `0x4000C008` | `RESETS_RESET_DONE` | Check if peripheral is out of reset |
| `0x400140CC` | `GPIO25_CTRL` | Function select for pin 25 |
| `0xD0000014` | `SIO_GPIO_OUT_SET` | Atomic set pin HIGH |
| `0xD0000018` | `SIO_GPIO_OUT_CLR` | Atomic set pin LOW |
| `0xD000001C` | `SIO_GPIO_OUT_XOR` | Atomic toggle pin |
| `0xD0000024` | `SIO_GPIO_OE_SET` | Enable pin as output |

All addresses verified against the [official RP2040 datasheet](https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf).

## License

The boot2 bootloader is derived from the Raspberry Pi Pico SDK (BSD-3-Clause).
All other code is original work, released under the MIT License.

## Author

Vaibhav Santosh Tiwari ([@orignalbox](https://github.com/orignalbox)) — Vicharak Campus Fellowship 2026
