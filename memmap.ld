MEMORY
{
    BOOT2 (rx)  : ORIGIN = 0x10000000, LENGTH = 0x100
    FLASH (rx)  : ORIGIN = 0x10000100, LENGTH = 2048K - 0x100
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 264K
}

/* stack starts at top of ram and grows down */
_stack_top = ORIGIN(RAM) + LENGTH(RAM);

ENTRY(_reset_handler)

SECTIONS
{
    /* 256-byte second-stage bootloader at flash origin */
    .boot2 : {
        KEEP(*(.boot2))
    } > BOOT2

    /* code and vector table */
    .text : {
        KEEP(*(.vectors))
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
    } > FLASH

    /* initialized globals loaded from flash to ram */
    __data_load = LOADADDR(.data);
    .data : {
        __data_start = .;
        *(.data*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM AT> FLASH

    /* uninitialized globals zeroed out in ram */
    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    /DISCARD/ : {
        *(.ARM.attributes)
        *(.comment)
        *(.ARM.exidx*)
    }
}
