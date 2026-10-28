# RP2040 Bare-Metal — How It Actually Works

My notes from learning bare-metal programming on the Vicharak Shrike Lite.

---

## How I Got Here (My Learning Path)

First I understood that there are mainly three things: CPU, SRAM, and Flash. Then there is the bus which connects all of this to the CPU. Then we need a bootloader which is like the entry point or the `int main` of a program. Then there is boot2 which is like GRUB — it helps configure what to run. And then there is the program which is like the OS. This is all with abstraction — then I needed to go deeper into how each part actually works at the hardware level.

## What is the RP2040, Physically?

It's a tiny piece of silicon with millions of transistors. Inside it there are a few major blocks:

- **CPU** (Cortex-M0+) — the thing that reads instructions and executes them. It can do math, move data, and talk to the bus.
- **SRAM** (264KB) — fast memory where your variables live. Disappears when power is off.
- **Flash** (external, 2MB) — slow storage chip soldered NEXT to the RP2040. Your program is stored here. Survives power-off.

## What is a Bus?

Imagine a highway connecting the CPU to everything else. The CPU puts an **address** on the highway (like a street number) and either reads or writes 32 bits of data. That's it. That's the bus.

Every address maps to *something*:
- `0x20000000` → this is SRAM. Reading/writing here changes your variables.
- `0xD0000014` → this is NOT memory. This is a **hardware register**. Writing `(1 << 25)` here physically makes pin 25 go HIGH — electrons flow, voltage appears on the metal pin, LED lights up.

**That's the entire trick of embedded programming.** The CPU doesn't have special "turn on LED" instructions. It just writes a number to an address, and the hardware wired to that address reacts.

## What is a Bootloader?

When power comes on, the CPU needs to start *somewhere*. It can't read your program from flash directly — the flash chip speaks a protocol (SPI) that needs to be configured first.

So the boot process is:

1. **ROM bootloader** (burned into the chip at the factory, you can't change it) — wakes up, reads the first 256 bytes from flash using slow, basic SPI
2. **boot2** (those 256 bytes you provide) — configures flash for fast reads so the CPU can execute code directly from flash
3. **Your program** — now the CPU can run your code

Think of it like: **the ROM is the BIOS, boot2 is GRUB, your code is the OS.**

---

## The Three Things Inside the Chip

- **CPU** (Cortex-M0+) — reads instructions, executes them, talks to the bus
- **SRAM** (264KB at `0x20000000`) — fast memory, variables live here, gone when power is off
- **Flash** (external, 2MB at `0x10000000`) — slow storage chip soldered NEXT to the RP2040, program stored here, survives power-off

## What is a Bus?

A highway connecting the CPU to everything else. The CPU puts an **address** on the highway and either reads or writes 32 bits of data.

Every address maps to something:
- `0x20000000` → SRAM. Reading/writing here changes variables.
- `0xD0000014` → NOT memory. This is a **hardware register**. Writing `(1 << 25)` here physically makes pin 25 go HIGH — electrons flow, LED lights up.

**The entire trick of embedded programming:** the CPU doesn't have special "turn on LED" instructions. It just writes a number to an address, and the hardware wired to that address reacts.

## What is a Bootloader?

When power comes on, the CPU needs to start somewhere. It can't read your program from flash directly — the flash chip speaks a protocol (SPI) that needs to be configured first.

---

## The Boot Chain — What Actually Happens Electrically

**Power comes on. Now what?**

The CPU is a state machine. It has a **Program Counter (PC)** — a register that says "which address am I reading my next instruction from?" When power hits, the hardware forces PC to `0x00000000`. That's not a choice — it's hardwired into the silicon.

### Stage 0: ROM Bootloader (you don't write this)

Address `0x00000000` is the **Boot ROM** — 16KB of code burned into the chip at the factory. You can read it, you can never change it. Raspberry Pi wrote this code.

What it does:
1. Checks some GPIO pins and USB to see if someone wants to enter "programming mode" (this is why holding BOOT works)
2. If not, it tries to read from the external flash chip
3. But here's the problem — **the flash chip is a separate physical IC** connected to the RP2040 by 6 wires (QSPI). The ROM doesn't know what kind of flash chip is on the board. Different flash chips need different commands.
4. So the ROM does the bare minimum: reads the **first 256 bytes** from flash using the simplest, slowest SPI protocol (every chip supports this)
5. It checks: do bytes 252-255 contain a valid CRC32 checksum of bytes 0-251? If not → it gives up and enters USB bootloader mode (board shows up as `RPI-RP2` drive on your PC)
6. If yes → it **executes those 256 bytes**

### Stage 1: boot2 (you provide this, 256 bytes max)

This is the code the ROM just loaded. Its ONLY job:

1. **Configure the QSPI flash controller** (called SSI — Synchronous Serial Interface, at address `0x18000000`) so the CPU can read flash FAST and in XIP mode
2. **XIP = eXecute In Place** — after boot2 runs, the CPU can treat flash like memory. When the CPU reads address `0x10000100`, the hardware automatically sends a read command to the flash chip, gets the data back, and gives it to the CPU. The CPU doesn't know it's reading from an external chip — it just sees an address.
3. **Jump to `0x10000100`** — your actual program

For our project, we borrow a pre-made boot2 because writing flash configuration code requires knowing the specific flash chip's datasheet. This is the ONE part we don't write from scratch.

### Stage 2: Vector Table + crt0 (you write this)

The CPU expects a **vector table** at the start of your program (`0x10000100`). This is an ARM Cortex-M thing — it's just an array of addresses:

```
Address          Contains             Meaning
0x10000100       0x20042000           "Put the stack pointer HERE"
0x10000104       0x100001XX           "Jump to THIS address to start"
0x10000108       address              "Jump here if NMI happens"
0x1000010C       address              "Jump here if a fault happens"
...
```

The CPU reads word 0 → loads it into the **Stack Pointer** (SP). The stack is where function calls store return addresses and local variables. It grows downward from the top of SRAM (`0x20042000` = `0x20000000 + 264KB`).

The CPU reads word 1 → loads it into the **Program Counter** (PC). This is your **reset handler** — the first real instruction that runs.

The reset handler does:
1. **Zero the `.bss` section** — C says uninitialized globals are 0. The compiler puts them in a section called `.bss`. But flash doesn't store zeros (waste of space), so your startup code fills that RAM region with zeros.
2. **Copy `.data` from flash to RAM** — initialized globals like `int x = 42` need to live in RAM (so you can modify them), but their initial values are stored in flash. Startup copies them over.
3. **Call `main()`**

### Stage 3: main() (you write this)

Now you're in C land. You talk to hardware by writing to addresses:

1. **Un-reset the GPIO subsystem** — write to `0x4000C000`
2. **Tell pin 25 to connect to SIO** — write to `0x400140CC`
3. **Enable pin 25 as output** — write to `0xD0000024`
4. **Toggle pin 25 forever** — write to `0xD000001C` in a loop

---

## The Files We Need (in boot order)

| File | What it is | Who runs it |
|---|---|---|
| `boot2.S` | Configures flash, borrowed | ROM loads + executes it |
| `crt0.S` | Vector table + reset handler | CPU reads table, jumps to handler |
| `main.c` | Your actual LED blink logic | Called by crt0 |
| `rp2040.h` | Address cheat sheet | Included by main.c |
| `memmap.ld` | Tells linker what goes where | Used at compile time |
| `Makefile` | Build commands | Used by you |

---

## Key Addresses (the whole project boils down to these)

| Address | Name | What it does |
|---|---|---|
| `0x4000C000` | RESETS_RESET | Un-reset GPIO subsystem (clear bit to wake it up) |
| `0x4000C008` | RESETS_RESET_DONE | Check if peripheral finished waking up |
| `0x400140CC` | GPIO25_CTRL | Tell pin 25 which peripheral to connect to (FUNCSEL=5 for SIO) |
| `0xD0000014` | SIO_GPIO_OUT_SET | Set pin HIGH (atomic, 1 cycle) |
| `0xD0000018` | SIO_GPIO_OUT_CLR | Set pin LOW (atomic, 1 cycle) |
| `0xD000001C` | SIO_GPIO_OUT_XOR | Toggle pin (atomic, 1 cycle) |
| `0xD0000024` | SIO_GPIO_OE_SET | Enable pin as output |
