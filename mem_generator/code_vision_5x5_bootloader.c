#include <stdint.h>

static volatile uint8_t *const IMAGE_BASE = (volatile uint8_t *)0x00001000u;
static volatile uint32_t *const ACCEL_PIX_IN = (volatile uint32_t *)0x00012024u;
static volatile uint32_t *const ACCEL_MAC_OUT = (volatile uint32_t *)0x00012028u;
static volatile uint32_t *const UART_TX_DATA = (volatile uint32_t *)0x00015000u;
static volatile uint32_t *const UART_TX_STAT = (volatile uint32_t *)0x00015004u;
static volatile uint32_t *const WARM_RESET_PENDING = (volatile uint32_t *)0x00016010u;
static volatile uint32_t *const WARM_RESET_CLEAR = (volatile uint32_t *)0x00016014u;

enum {
    IMAGE_BYTES = 49152u,
    IMG_WIDTH = 256u,
    WARMUP_PIXELS = (4u * IMG_WIDTH) + 4u
};

static inline void acknowledge_warm_reset(void)
{
    if ((*WARM_RESET_PENDING & 0x1u) != 0u) {
        *WARM_RESET_CLEAR = 1u;
    }
}

static inline uint32_t read_image_byte(uint32_t index)
{
    return IMAGE_BASE[index];
}

static inline void uart_send_byte(uint32_t value)
{
    while ((*UART_TX_STAT & 0x1u) != 0u) {
        asm volatile("nop");
    }

    *UART_TX_DATA = value;
}

int main(void)
{
    uint32_t final_pixel = 0u;

    acknowledge_warm_reset();

    for (uint32_t i = 0u; i < WARMUP_PIXELS; ++i) {
        uint32_t word_index = i >> 2;
        uint32_t byte_offset = i & 0x3u;
        uint32_t pixel_val = (read_image_byte(word_index * 4u + byte_offset) & 0xFFu);

        *ACCEL_PIX_IN = pixel_val;
    }
    // asm volatile("nop");
    // asm volatile("nop");
    // asm volatile("nop");

    for (uint32_t i = WARMUP_PIXELS; i < IMAGE_BYTES; ++i) {
        uint32_t word_index = i >> 2;
        uint32_t byte_offset = i & 0x3u;
        uint32_t pixel_val = (read_image_byte(word_index * 4u + byte_offset) & 0xFFu);

        *ACCEL_PIX_IN = pixel_val;
        if(i == WARMUP_PIXELS) {
            asm volatile("nop");
            asm volatile("nop");
            asm volatile("nop");
        }
        // asm volatile("nop");
        // asm volatile("nop");
        // asm volatile("nop");

        final_pixel = *ACCEL_MAC_OUT;
        uart_send_byte(final_pixel);
    }

    for (uint32_t i = 0u; i < WARMUP_PIXELS; ++i) {
        *ACCEL_PIX_IN = 0u;
        asm volatile("nop");
        asm volatile("nop");
        asm volatile("nop");

        final_pixel = *ACCEL_MAC_OUT;
        uart_send_byte(final_pixel);
    }

    while (1) {
        asm volatile("nop");
    }

    return 0;
}