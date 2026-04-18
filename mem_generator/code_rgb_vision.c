#include <stdint.h>

// Bootloader writes input bytes starting here.
static volatile uint32_t *const IMAGE_BASE_WORDS = (volatile uint32_t *)0x00001000u;

// Accelerator MMIO
static volatile uint32_t *const ACCEL_PUSH = (volatile uint32_t *)0x00012024u;
static volatile uint32_t *const ACCEL_READ = (volatile uint32_t *)0x00012028u;

// UART MMIO
static volatile uint32_t *const UART_TX_DATA = (volatile uint32_t *)0x00015000u;
static volatile uint32_t *const UART_TX_STAT = (volatile uint32_t *)0x00015004u;

// Warm-reset handshake MMIO
static volatile uint32_t *const WARM_RESET_PENDING = (volatile uint32_t *)0x00016010u;
static volatile uint32_t *const WARM_RESET_CLEAR = (volatile uint32_t *)0x00016014u;

// VGA VRAM base (word-indexed RGB pixels)
static volatile uint32_t *const VRAM_BASE_WORDS = (volatile uint32_t *)0x00030000u;

// 128x96 RGB image, one 32-bit word per pixel (0x00RRGGBB).
enum {
    IMG_WIDTH = 128,
    IMG_HEIGHT = 96,
    TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT,
    WARMUP_PIXELS = (4 * IMG_WIDTH) + 2
};

static inline void acknowledge_warm_reset(void)
{
    if ((*WARM_RESET_PENDING & 0x1u) != 0u) {
        *WARM_RESET_CLEAR = 1u;
    }
}

static inline void uart_send_byte(uint8_t value)
{
    while ((*UART_TX_STAT & 0x1u) != 0u) {
        asm volatile("nop");
    }
    *UART_TX_DATA = (uint32_t)value;
}

static inline void uart_send_rgb(uint32_t pixel)
{
    uint8_t r = (uint8_t)((pixel >> 16) & 0xFFu);
    uint8_t g = (uint8_t)((pixel >> 8) & 0xFFu);
    uint8_t b = (uint8_t)(pixel & 0xFFu);

    uart_send_byte(r);
    uart_send_byte(g);
    uart_send_byte(b);
}

int main(void)
{
    uint32_t out_idx = 0;

    acknowledge_warm_reset();

    for (uint32_t i = 0; i < (TOTAL_PIXELS + WARMUP_PIXELS); ++i) {
        uint32_t pixel = (i < TOTAL_PIXELS) ? IMAGE_BASE_WORDS[i] : 0u;

        *ACCEL_PUSH = pixel;

        asm volatile("nop");
        asm volatile("nop");
        asm volatile("nop");

        if (i >= WARMUP_PIXELS) {
            uint32_t filtered = *ACCEL_READ;

            if (out_idx < TOTAL_PIXELS) {
                VRAM_BASE_WORDS[out_idx] = filtered;
                out_idx++;
            }

            uart_send_rgb(filtered);
        }
    }

    while (1) {
        asm volatile("nop");
    }

    return 0;
}