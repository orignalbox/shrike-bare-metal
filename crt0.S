.syntax unified
.cpu    cortex-m0plus
.thumb

// vector table placed right after boot2 at 0x10000100
.section .vectors, "ax"
.align 2
.global __vectors

__vectors:
    .word   _stack_top          // initial sp at top of sram
    .word   _reset_handler      // reset entry point
    .word   _hang               // nmi
    .word   _hang               // hardfault
    .word   0
    .word   0
    .word   0
    .word   0
    .word   0
    .word   0
    .word   0
    .word   _hang               // svcall
    .word   0
    .word   0
    .word   _hang               // pendsv
    .word   _hang               // systick
    // irq 0 to 31
    .rept   32
    .word   _hang
    .endr

.section .text
.thumb_func
.global _reset_handler
_reset_handler:
    // zero out .bss section in ram
    ldr     r0, =__bss_start
    ldr     r1, =__bss_end
    movs    r2, #0
.Lzero_bss:
    cmp     r0, r1
    bge     .Lzero_bss_done
    stm     r0!, {r2}
    b       .Lzero_bss
.Lzero_bss_done:

    // copy .data from flash into ram
    ldr     r0, =__data_start
    ldr     r1, =__data_load
    ldr     r2, =__data_end
.Lcopy_data:
    cmp     r0, r2
    bge     .Lcopy_data_done
    ldm     r1!, {r3}
    stm     r0!, {r3}
    b       .Lcopy_data
.Lcopy_data_done:

    // jump to main
    bl      main

.thumb_func
.global _hang
_hang:
    wfi
    b       _hang
