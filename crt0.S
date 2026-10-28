/*
 * crt0.S — Minimal C runtime startup for RP2040 (Cortex-M0+)
 *
 * This file provides:
 *   1. The ARM vector table (stack pointer + exception handlers)
 *   2. The Reset_Handler that initializes RAM and calls main()
 *
 * The Cortex-M0+ boot sequence:
 *   - After boot2 finishes, CPU reads the vector table from 0x10000100
 *   - Word at offset 0x00 → loaded into SP (Stack Pointer)
 *   - Word at offset 0x04 → loaded into PC (jumps to Reset_Handler)
 *   - Reset_Handler zeros .bss, copies .data from flash→RAM, calls main()
 */

.syntax unified
.cpu    cortex-m0plus
.thumb

/* =========================================================================
 * Vector Table — must be at the very start of .vectors section
 * The linker script places this at 0x10000100 (right after boot2).
 *
 * Cortex-M0+ supports 16 system exceptions + up to 32 external IRQs.
 * For a minimal blink, we only need the first 2 words + fault handlers.
 * All unused vectors point to _hang (infinite loop).
 * ========================================================================= */
.section .vectors, "ax"
.align 2
.global __vectors

__vectors:
    .word   _stack_top          /*  0: Initial Stack Pointer (top of SRAM)      */
    .word   _reset_handler      /*  1: Reset — entry point after boot           */
    .word   _hang               /*  2: NMI                                      */
    .word   _hang               /*  3: HardFault                                */
    .word   0                   /*  4: Reserved                                 */
    .word   0                   /*  5: Reserved                                 */
    .word   0                   /*  6: Reserved                                 */
    .word   0                   /*  7: Reserved                                 */
    .word   0                   /*  8: Reserved                                 */
    .word   0                   /*  9: Reserved                                 */
    .word   0                   /* 10: Reserved                                 */
    .word   _hang               /* 11: SVCall                                   */
    .word   0                   /* 12: Reserved                                 */
    .word   0                   /* 13: Reserved                                 */
    .word   _hang               /* 14: PendSV                                   */
    .word   _hang               /* 15: SysTick                                  */
    /* IRQ 0-31 — all default to hang */
    .word   _hang               /* IRQ  0 */
    .word   _hang               /* IRQ  1 */
    .word   _hang               /* IRQ  2 */
    .word   _hang               /* IRQ  3 */
    .word   _hang               /* IRQ  4 */
    .word   _hang               /* IRQ  5 */
    .word   _hang               /* IRQ  6 */
    .word   _hang               /* IRQ  7 */
    .word   _hang               /* IRQ  8 */
    .word   _hang               /* IRQ  9 */
    .word   _hang               /* IRQ 10 */
    .word   _hang               /* IRQ 11 */
    .word   _hang               /* IRQ 12 */
    .word   _hang               /* IRQ 13 */
    .word   _hang               /* IRQ 14 */
    .word   _hang               /* IRQ 15 */
    .word   _hang               /* IRQ 16 */
    .word   _hang               /* IRQ 17 */
    .word   _hang               /* IRQ 18 */
    .word   _hang               /* IRQ 19 */
    .word   _hang               /* IRQ 20 */
    .word   _hang               /* IRQ 21 */
    .word   _hang               /* IRQ 22 */
    .word   _hang               /* IRQ 23 */
    .word   _hang               /* IRQ 24 */
    .word   _hang               /* IRQ 25 */
    .word   _hang               /* IRQ 26 */
    .word   _hang               /* IRQ 27 */
    .word   _hang               /* IRQ 28 */
    .word   _hang               /* IRQ 29 */
    .word   _hang               /* IRQ 30 */
    .word   _hang               /* IRQ 31 */

/* =========================================================================
 * Reset Handler — the first real code that runs
 *
 * Responsibilities:
 *   1. Zero the .bss section (uninitialized globals → must be 0)
 *   2. Copy .data section from flash (LMA) to RAM (VMA)
 *   3. Call main()
 *   4. If main() returns, hang forever
 * ========================================================================= */
.section .text
.thumb_func
.global _reset_handler
_reset_handler:
    /* --- Zero .bss section --- */
    ldr     r0, =__bss_start
    ldr     r1, =__bss_end
    movs    r2, #0
.Lzero_bss:
    cmp     r0, r1
    bge     .Lzero_bss_done
    stm     r0!, {r2}           /* Store 0 at [r0], r0 += 4 */
    b       .Lzero_bss
.Lzero_bss_done:

    /* --- Copy .data from flash to RAM --- */
    ldr     r0, =__data_start   /* RAM destination (VMA) */
    ldr     r1, =__data_load    /* Flash source (LMA)    */
    ldr     r2, =__data_end     /* RAM end               */
.Lcopy_data:
    cmp     r0, r2
    bge     .Lcopy_data_done
    ldm     r1!, {r3}           /* Load word from flash, r1 += 4 */
    stm     r0!, {r3}           /* Store to RAM, r0 += 4         */
    b       .Lcopy_data
.Lcopy_data_done:

    /* --- Call main() --- */
    bl      main

    /* --- If main() returns, fall through to hang --- */

/* =========================================================================
 * Hang — infinite loop for unhandled exceptions / main() return
 * WFI (Wait For Interrupt) puts the core into low-power sleep.
 * ========================================================================= */
.thumb_func
.global _hang
_hang:
    wfi
    b       _hang
