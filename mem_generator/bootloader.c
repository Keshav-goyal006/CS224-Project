#include <stdint.h>

static volatile uint32_t *const SWITCHES = (volatile uint32_t *)0x00016000u;
static volatile uint32_t *const WARM_RESET_PENDING = (volatile uint32_t *)0x00016010u;
static volatile uint32_t *const UART_RX_DATA = (volatile uint32_t *)0x00015008u;
static volatile uint32_t *const UART_RX_STAT = (volatile uint32_t *)0x0001500Cu;
static volatile uint8_t *const IMAGE_BASE = (volatile uint8_t *)0x00001000u;

enum {
    IMAGE_BYTES = 49152u,
    SWITCH_MASK = 0x00008000u
};

static inline uint32_t mmio_read32(volatile uint32_t *addr)
{
    uint32_t value = *addr;
    asm volatile("nop");
    asm volatile("nop");
    return value;
}

void bootloader_main(void)
{
    if (mmio_read32(WARM_RESET_PENDING) & 0x1u) {
        return;
    }

    while ((mmio_read32(SWITCHES) & SWITCH_MASK) == 0u) {
        asm volatile("nop");
    }

    for (uint32_t i = 0; i < IMAGE_BYTES; ++i) {
        while ((mmio_read32(UART_RX_STAT) & 0x01u) == 0u) {
            asm volatile("nop");
        }

        IMAGE_BASE[i] = (uint8_t)mmio_read32(UART_RX_DATA);
    }

    while ((mmio_read32(SWITCHES) & SWITCH_MASK) != 0u) {
        asm volatile("nop");
    }
}