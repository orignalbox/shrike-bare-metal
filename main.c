/*
 * main.c — Bare-metal LED blink on Vicharak Shrike Lite (RP2040)
 *
 * Zero SDK. Zero libraries. Just direct register manipulation.
 *
 * What this does:
 *   1. Releases IO_BANK0 and PADS_BANK0 from reset
 *   2. Connects GPIO25 to the SIO block (function select)
 *   3. Enables GPIO25 as an output
 *   4. Toggles the pin forever using the single-cycle XOR register
 *
 * The LED pin may vary on Shrike Lite vs standard Pico.
 * GPIO25 is the onboard LED on Raspberry Pi Pico. Change if needed.
 */

#include "rp2040.h"

/* Which GPIO pin drives the LED — change this if Shrike Lite uses a different pin */
#define LED_PIN  25u

/*
 * Busy-wait delay.
 * At the default 12 MHz ring oscillator (no PLL configured),
 * each NOP loop iteration takes ~4 cycles (subs + bne + nop + loop overhead).
 * So delay(1000000) ≈ 1000000 * 4 / 12000000 ≈ 0.33 seconds.
 */
static void delay(volatile uint32_t count)
{
    while (count--) {
        __asm__ volatile ("nop");
    }
}

int main(void)
{
    /*
     * STEP 1: Release peripherals from reset.
     *
     * The RP2040 boots with almost everything held in reset.
     * We need two subsystems:
     *   - IO_BANK0  (bit 5): GPIO function multiplexer
     *   - PADS_BANK0 (bit 8): GPIO pad electrical drivers
     *
     * To release: CLEAR the bits in RESETS_RESET (bit=1 means "hold in reset").
     * Then spin until RESETS_RESET_DONE confirms they're alive.
     */
    uint32_t reset_bits = RESETS_IO_BANK0_BIT | RESETS_PADS_BANK0_BIT;

    RESETS_RESET &= ~reset_bits;

    while ((RESETS_RESET_DONE & reset_bits) != reset_bits) {
        /* Wait for both peripherals to finish their reset sequence */
    }

    /*
     * STEP 2: Route GPIO25 to the SIO block.
     *
     * Each physical pin can be connected to different peripherals
     * (SPI, UART, I2C, PWM, PIO, or SIO). We write FUNCSEL=5
     * into the GPIO25_CTRL register to select SIO.
     *
     * GPIO_CTRL(25) = IO_BANK0_BASE + 0x04 + 25*8 = 0x400140CC
     */
    GPIO_CTRL(LED_PIN) = FUNCSEL_SIO;

    /*
     * STEP 3: Enable the output driver.
     *
     * SIO_GPIO_OE_SET is an atomic set register — writing a 1
     * to bit 25 enables the output driver for that pin without
     * affecting any other pins. No read-modify-write needed.
     */
    SIO_GPIO_OE_SET = (1u << LED_PIN);

    /*
     * STEP 4: Blink forever.
     *
     * SIO_GPIO_OUT_XOR is the atomic toggle register.
     * Writing (1 << 25) flips the output state of GPIO25
     * in a SINGLE CPU cycle. This is the fastest possible
     * way to toggle a pin on the RP2040.
     */
    for (;;) {
        SIO_GPIO_OUT_XOR = (1u << LED_PIN);
        delay(1000000);
    }

    /* Never reached */
    return 0;
}
