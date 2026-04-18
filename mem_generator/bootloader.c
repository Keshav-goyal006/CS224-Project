#include <stdint.h>

static volatile uint32_t *const SWITCHES = (volatile uint32_t *)0x00006000u;
static volatile uint32_t *const WARM_RESET_PENDING = (volatile uint32_t *)0x00006010u;
static volatile uint32_t *const UART_RX_DATA = (volatile uint32_t *)0x00005008u;
static volatile uint32_t *const UART_RX_STAT = (volatile uint32_t *)0x0000500Cu;
static volatile uint8_t *const IMAGE_BASE = (volatile uint8_t *)0x00001000u;

enum {
    IMAGE_BYTES = 3072u,
    SWITCH_MASK = 0x00008000u
};

void bootloader_main(void)
{
    if ((*WARM_RESET_PENDING) & 0x1u) {
        return;
    }

    if (((*SWITCHES) & SWITCH_MASK) == 0u) {
        return;
    }

    for (uint32_t i = 0; i < IMAGE_BYTES; ++i) {
        while (((*UART_RX_STAT) & 0x01u) == 0u) {
            asm volatile("nop");
        }

        IMAGE_BASE[i] = (uint8_t)(*UART_RX_DATA);
    }

    while (((*SWITCHES) & SWITCH_MASK) != 0u) {
        asm volatile("nop");
    }
}