/*
 * boot2.S — Minimal second-stage bootloader for RP2040
 *
 * This is a simplified, self-contained version that configures the SSI
 * (Synchronous Serial Interface) for standard SPI XIP reads from flash.
 *
 * Based on the Raspberry Pi Pico SDK boot2_w25q080.S (BSD-3-Clause),
 * but rewritten to be fully standalone — no SDK header dependencies.
 *
 * What it does:
 *   1. Disables SSI to allow reconfiguration
 *   2. Sets up SSI for standard 03h read command in XIP mode
 *   3. Re-enables SSI
 *   4. Jumps to the start of the main application (0x10000100)
 *
 * The ROM bootloader:
 *   - Reads these 256 bytes from the start of flash
 *   - Verifies CRC32 of the first 252 bytes against bytes 252-255
 *   - If valid, executes this code
 *   - This code then configures flash for fast XIP reads
 *   - Then jumps to our real program at 0x10000100
 *
 * Size constraint: code must fit in 252 bytes (last 4 = CRC32).
 * The Makefile/build script will pad to 252 bytes and append the checksum.
 */

.syntax unified
.cpu    cortex-m0plus
.thumb

.section .boot2, "ax"

/* SSI (Synchronous Serial Interface) registers */
.equ SSI_BASE,          0x18000000
.equ SSI_SSIENR,        0x08    /* SSI Enable: 0=disable, 1=enable             */
.equ SSI_BAUDR,         0x14    /* Baud rate divisor                           */
.equ SSI_CTRLR0,        0x00    /* Control register 0                          */
.equ SSI_CTRLR1,        0x04    /* Control register 1 (number of data frames)  */
.equ SSI_SPI_CTRLR0,    0xF4    /* SPI-specific control                        */

/* XIP base address — where the CPU will fetch instructions from flash */
.equ XIP_BASE,          0x10000000

/* The vector table starts right after boot2 (256 bytes in) */
.equ APP_ENTRY,         0x10000100

/*
 * CTRLR0 configuration:
 *   DFS_32 = 31 (32 clocks per data frame = 32-bit transfers)
 *   TMOD   = 3 (EEPROM read mode: TX then RX)
 *   bits [20:16] = 31 (data frame size)
 *   bits [9:8]   = 3  (EEPROM read)
 */
.equ CTRLR0_VAL,        ((31 << 16) | (3 << 8))

/*
 * SPI_CTRLR0 configuration for standard SPI reads:
 *   ADDR_L = 24 bits (3-byte address)
 *   INST_L = 8 bits  (1-byte command)
 *   TRANS_TYPE = standard (command + address in standard SPI)
 *   XIP_CMD = 0x03  (standard read)
 *   WAIT_CYCLES = 0
 *
 *   bits [4:2]   = 6  (ADDR_L = 24 bits, encoded as 24/4 = 6)
 *   bits [9:8]   = 2  (INST_L = 8 bits)
 *   bits [24]    = 0x03 shifted into CMD field
 */
.equ SPI_CTRLR0_VAL,    ((0x03 << 24) | (0 << 11) | (6 << 2) | (2 << 8))

.global _boot2_entry
.thumb_func
_boot2_entry:
    /* Disable SSI for reconfiguration */
    ldr     r3, =SSI_BASE
    movs    r0, #0
    str     r0, [r3, #SSI_SSIENR]

    /* Set baud rate divisor to 2 (fastest possible: clk_sys / 2) */
    movs    r0, #2
    str     r0, [r3, #SSI_BAUDR]

    /* Configure CTRLR0: 32-bit frames, EEPROM read mode */
    ldr     r0, =CTRLR0_VAL
    str     r0, [r3, #SSI_CTRLR0]

    /* CTRLR1: 0 data frames (we just want XIP, not bulk reads) */
    movs    r0, #0
    str     r0, [r3, #SSI_CTRLR1]

    /* SPI_CTRLR0: standard 0x03 read, 24-bit address, 8-bit instruction */
    /*
     * NOTE: Cortex-M0+ STR only supports offsets up to 124 (5-bit * 4).
     * SSI_SPI_CTRLR0 is at offset 0xF4 (244), so we compute the full address.
     */
    ldr     r0, =SPI_CTRLR0_VAL
    ldr     r1, =(SSI_BASE + SSI_SPI_CTRLR0)
    str     r0, [r1]

    /* Re-enable SSI */
    movs    r0, #1
    str     r0, [r3, #SSI_SSIENR]

    /*
     * Jump to the application vector table.
     *
     * The vector table at 0x10000100 contains:
     *   [0] = initial SP
     *   [4] = reset handler address
     *
     * We load SP from [0], then load and branch to the reset handler at [4].
     * This mirrors what the Cortex-M0+ would do on a true hardware reset.
     */
    ldr     r0, =APP_ENTRY
    ldr     r1, [r0]            /* r1 = initial stack pointer from vector table */
    msr     msp, r1             /* Set Main Stack Pointer                       */
    ldr     r1, [r0, #4]        /* r1 = reset handler address                   */
    bx      r1                  /* Jump to reset handler                        */

/*
 * Padding and checksum:
 * The Makefile will:
 *   1. Assemble this into a raw binary
 *   2. Pad to exactly 252 bytes
 *   3. Compute CRC32 of those 252 bytes
 *   4. Append the 4-byte CRC (total = 256 bytes)
 */

.align 2
.global _boot2_end
_boot2_end:
