#include <stdint.h>
#include "image_data.h"

volatile uint32_t* const ACCEL_PIX_IN  = (uint32_t*)0x00002024;
volatile uint32_t* const ACCEL_MAC_OUT = (uint32_t*)0x00002028;
volatile uint32_t* const UART_TX_DATA  = (uint32_t*)0x00005000;
volatile uint32_t* const UART_TX_STAT  = (uint32_t*)0x00005004;

int main(void) {
    register int i asm("s1");
    register uint32_t final_pixel asm("s4");

    // Warm-up pixels for the 5x5 line buffers
    for (i = 0; i < 258; i++) {
        uint32_t pixel_val = image_pixels[i];
        *ACCEL_PIX_IN = pixel_val;
        asm volatile("nop");
        asm volatile("nop");
        asm volatile("nop");
    }

    // Valid pixels
    for (i = 258; i < 3072; i++) {
        uint32_t pixel_val = image_pixels[i];
        *ACCEL_PIX_IN = pixel_val;
        asm volatile("nop");
        asm volatile("nop");
        asm volatile("nop");

        final_pixel = *ACCEL_MAC_OUT;

        while ((*UART_TX_STAT & 0x01) == 1) {
            asm volatile("nop");
        }
        *UART_TX_DATA = final_pixel;
    }

    // Flush the tail
    for (i = 0; i < 258; i++) {
        *ACCEL_PIX_IN = 0;
        asm volatile("nop");
        asm volatile("nop");
        asm volatile("nop");

        final_pixel = *ACCEL_MAC_OUT;

        while ((*UART_TX_STAT & 0x01) == 1) {
            asm volatile("nop");
        }
        *UART_TX_DATA = final_pixel;
    }

    while (1);
    return 0;
}