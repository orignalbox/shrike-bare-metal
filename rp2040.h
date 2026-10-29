#ifndef RP2040_H
#define RP2040_H

#include <stdint.h>

// helper macro to read/write memory mapped 32-bit registers
#define REG(addr) (*(volatile uint32_t *)(addr))

// subsystem reset controller (datasheet 2.14)
#define RESETS_BASE              0x4000C000u
#define RESETS_RESET             REG(RESETS_BASE + 0x00)
#define RESETS_WDSEL             REG(RESETS_BASE + 0x04)
#define RESETS_RESET_DONE        REG(RESETS_BASE + 0x08)

#define RESETS_IO_BANK0_BIT      (1u << 5)   // gpio mux
#define RESETS_PADS_BANK0_BIT    (1u << 8)   // pad electrical config

// gpio function multiplexer (datasheet 2.19.6)
#define IO_BANK0_BASE            0x40014000u
#define GPIO_CTRL(n)             REG(IO_BANK0_BASE + 0x04 + (n) * 8)
#define FUNCSEL_SIO              5u          // 5 connects gpio to sio

// pad electrical config (datasheet 2.19.5)
#define PADS_BANK0_BASE          0x4001C000u
#define PADS_GPIO(n)             REG(PADS_BANK0_BASE + 0x04 + (n) * 4)
#define PADS_OD_BIT              (1u << 7)
#define PADS_IE_BIT              (1u << 6)

// single cycle io block (datasheet 2.3.1)
#define SIO_BASE                 0xD0000000u
#define SIO_GPIO_IN              REG(SIO_BASE + 0x004)
#define SIO_GPIO_OUT             REG(SIO_BASE + 0x010)
#define SIO_GPIO_OUT_SET         REG(SIO_BASE + 0x014)   // atomic set high
#define SIO_GPIO_OUT_CLR         REG(SIO_BASE + 0x018)   // atomic set low
#define SIO_GPIO_OUT_XOR         REG(SIO_BASE + 0x01C)   // atomic toggle
#define SIO_GPIO_OE              REG(SIO_BASE + 0x020)
#define SIO_GPIO_OE_SET          REG(SIO_BASE + 0x024)   // enable output
#define SIO_GPIO_OE_CLR          REG(SIO_BASE + 0x028)

#endif
