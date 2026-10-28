/*
 * memmap.ld — Linker script for bare-metal RP2040
 *
 * Memory layout:
 *   0x10000000 - 0x100000FF : boot2 (256-byte second-stage bootloader)
 *   0x10000100 - ...        : Our application (vector table + code + rodata)
 *   0x20000000 - 0x20041FFF : SRAM (264 KB = 0x42000 bytes)
 *
 * The RP2040 has 264KB of SRAM split across 6 banks,
 * but they're contiguous in the address space so we treat them as one block.
 */

MEMORY
{
    BOOT2 (rx)  : ORIGIN = 0x10000000, LENGTH = 0x100
    FLASH (rx)  : ORIGIN = 0x10000100, LENGTH = 2048K - 0x100
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 264K
}

/* Stack starts at the top of RAM (grows downward on ARM) */
_stack_top = ORIGIN(RAM) + LENGTH(RAM);   /* = 0x20042000 */

ENTRY(_reset_handler)

SECTIONS
{
    /* --- Second-stage bootloader: exactly 256 bytes at flash start --- */
    .boot2 : {
        __boot2_start = .;
        KEEP(*(.boot2))
        __boot2_end = .;
    } > BOOT2

    /* --- Application code + read-only data --- */
    .text : {
        KEEP(*(.vectors))       /* Vector table MUST be first */
        *(.text*)               /* All code */
        *(.rodata*)             /* String literals, const data */
        . = ALIGN(4);
    } > FLASH

    /*
     * --- Initialized data (.data) ---
     * Stored in FLASH (LMA) but copied to RAM (VMA) by crt0.S at startup.
     * __data_load = where it lives in flash
     * __data_start / __data_end = where it goes in RAM
     */
    __data_load = LOADADDR(.data);

    .data : {
        __data_start = .;
        *(.data*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM AT> FLASH

    /*
     * --- Uninitialized data (.bss) ---
     * Lives in RAM only. Zeroed by crt0.S at startup.
     */
    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    /* Discard standard library cruft we don't need */
    /DISCARD/ : {
        *(.ARM.attributes)
        *(.comment)
        *(.ARM.exidx*)
    }
}
