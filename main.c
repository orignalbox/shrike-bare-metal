#include "rp2040.h"

#define LED_PIN_SHRIKE  4u
#define LED_PIN_PICO    25u

static void delay(volatile uint32_t count)
{
    while (count--) {
        __asm__ volatile ("nop");
    }
}

int main(void)
{
    uint32_t reset_bits = RESETS_IO_BANK0_BIT | RESETS_PADS_BANK0_BIT;

    /* Release IO_BANK0 and PADS_BANK0 from reset */
    RESETS_RESET &= ~reset_bits;
    while ((RESETS_RESET_DONE & reset_bits) != reset_bits) {
    }

    /* Route GPIO lines to Single-Cycle I/O (SIO, FUNCSEL 5) */
    GPIO_CTRL(LED_PIN_SHRIKE) = FUNCSEL_SIO;
    GPIO_CTRL(LED_PIN_PICO)   = FUNCSEL_SIO;

    /* Configure GPIO lines as outputs */
    uint32_t led_mask = (1u << LED_PIN_SHRIKE) | (1u << LED_PIN_PICO);
    SIO_GPIO_OE_SET = led_mask;

    /* Atomic toggle loop */
    for (;;) {
        SIO_GPIO_OUT_XOR = led_mask;
        delay(1000000);
    }

    return 0;
}
