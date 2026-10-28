/*
 * rp2040.h — RP2040 bare-metal register definitions
 *
 * Every address here comes from the official RP2040 datasheet:
 * https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf
 *
 * No SDK. No libraries. Just raw memory-mapped hardware.
 */

#ifndef RP2040_H
#define RP2040_H

#include <stdint.h>

/* Helper: cast an address to a volatile 32-bit pointer and dereference */
#define REG(addr) (*(volatile uint32_t *)(addr))

/* =========================================================================
 * RESETS — Subsystem Reset Controller
 * Base: 0x4000C000   Datasheet: Section 2.14
 *
 * On power-up, almost ALL peripherals are held in reset to save power.
 * You MUST clear the relevant bit before touching any peripheral registers,
 * or the CPU will hang on a bus fault.
 * ========================================================================= */
#define RESETS_BASE              0x4000C000u
#define RESETS_RESET             REG(RESETS_BASE + 0x00)  /* Assert/deassert reset     */
#define RESETS_WDSEL             REG(RESETS_BASE + 0x04)  /* Watchdog reset select      */
#define RESETS_RESET_DONE        REG(RESETS_BASE + 0x08)  /* Reset completion status    */

/* Bit positions for peripherals we need */
#define RESETS_IO_BANK0_BIT      (1u << 5)   /* GPIO function mux            */
#define RESETS_PADS_BANK0_BIT    (1u << 8)   /* GPIO pad electrical config   */

/* =========================================================================
 * IO_BANK0 — GPIO Function Multiplexer
 * Base: 0x40014000   Datasheet: Section 2.19.6
 *
 * Each GPIO pin has two registers (8 bytes apart):
 *   STATUS (offset 0x00 + n*8) — read-only pin state
 *   CTRL   (offset 0x04 + n*8) — function select + overrides
 *
 * CTRL bits [4:0] = FUNCSEL: selects which peripheral drives the pin.
 *   0 = SPI,  1 = UART,  2 = I2C,  3 = PWM,
 *   4 = SIO (what we want),  5 = PIO0,  6 = PIO1,
 *   ... 31 = NULL (pin disconnected)
 *
 * CORRECTION: FUNCSEL=5 is SIO on the RP2040. Verified in datasheet Table 295.
 * ========================================================================= */
#define IO_BANK0_BASE            0x40014000u
#define GPIO_CTRL(n)             REG(IO_BANK0_BASE + 0x04 + (n) * 8)
#define FUNCSEL_SIO              5u

/* =========================================================================
 * PADS_BANK0 — Pad Electrical Configuration
 * Base: 0x4001C000   Datasheet: Section 2.19.5
 *
 * Controls drive strength, slew rate, pull-up/down, input enable,
 * and crucially: Output Disable (OD) bit.
 *
 * Register layout: 0x04 + n*4 for GPIO n
 * Default after reset: OD=0, IE=1, DRIVE=4mA, PUE=0, PDE=1, SCHMITT=1, SLEWFAST=0
 * For basic output, defaults are fine — OD is already 0 (output enabled).
 * ========================================================================= */
#define PADS_BANK0_BASE          0x4001C000u
#define PADS_GPIO(n)             REG(PADS_BANK0_BASE + 0x04 + (n) * 4)
#define PADS_OD_BIT              (1u << 7)   /* Output Disable: 1=disabled  */
#define PADS_IE_BIT              (1u << 6)   /* Input Enable: 1=enabled     */

/* =========================================================================
 * SIO — Single-Cycle I/O Block
 * Base: 0xD0000000   Datasheet: Section 2.3.1
 *
 * This is wired directly to the CPU's internal bus — register access
 * completes in a SINGLE clock cycle with zero wait states.
 *
 * The SET/CLR/XOR registers are atomic: you can modify individual bits
 * without a read-modify-write sequence. This is faster AND interrupt-safe.
 * ========================================================================= */
#define SIO_BASE                 0xD0000000u
#define SIO_GPIO_IN              REG(SIO_BASE + 0x004)   /* Read all pin states     */
#define SIO_GPIO_OUT             REG(SIO_BASE + 0x010)   /* Direct output value     */
#define SIO_GPIO_OUT_SET         REG(SIO_BASE + 0x014)   /* Atomic set bits HIGH    */
#define SIO_GPIO_OUT_CLR         REG(SIO_BASE + 0x018)   /* Atomic clear bits LOW   */
#define SIO_GPIO_OUT_XOR         REG(SIO_BASE + 0x01C)   /* Atomic toggle bits      */
#define SIO_GPIO_OE              REG(SIO_BASE + 0x020)   /* Output enable register  */
#define SIO_GPIO_OE_SET          REG(SIO_BASE + 0x024)   /* Atomic enable output    */
#define SIO_GPIO_OE_CLR          REG(SIO_BASE + 0x028)   /* Atomic disable output   */

#endif /* RP2040_H */
