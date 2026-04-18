#include <stdint.h>

// ---------------------------------------------------------
// NEW 64KB Memory Map Addresses
// ---------------------------------------------------------
volatile uint8_t* const IMAGE_BASE = (uint8_t*)0x00001000;

// Accelerator Base is 0x00012000
volatile uint32_t* const ACCEL_PIX_IN  = (uint32_t*)0x00012024; 
// volatile uint32_t* const ACCEL_TEMP = (uint32_t*)0x00012028; 
volatile uint32_t* const ACCEL_MAC_OUT = (uint32_t*)0x00012028;

// UART Base is 0x00015000
volatile uint32_t* const UART_TX_DATA  = (uint32_t*)0x00015000;
volatile uint32_t* const UART_TX_STAT  = (uint32_t*)0x00015004;
volatile uint32_t* const WARM_RESET_PENDING = (uint32_t*)0x00016010;
volatile uint32_t* const WARM_RESET_CLEAR   = (uint32_t*)0x00016014;

// ---------------------------------------------------------
// 256x192 Image Constants
// ---------------------------------------------------------
#define TOTAL_PIXELS 49152

// For a 9x9 kernel, warmup is 4 full rows + 4 pixels
// (4 * 256) + 4 = 1028 pixels.
#define WARMUP_PIXELS 1028 

static inline void acknowledge_warm_reset(void) {
    if (*WARM_RESET_PENDING) {
        *WARM_RESET_CLEAR = 1;
    }
}

int main() {
    register int i asm("s1");
    register uint32_t final_pixel asm("s4");

    acknowledge_warm_reset();
    *(volatile uint32_t*)0x00013000 = 0x0001; // Turn on LED0 when app code starts.

    // PHASE 1: WARM UP 
    for (i = 0; i < WARMUP_PIXELS; i++) {
        int word_index = i >> 2; 
        int byte_offset = i & 3; 
        uint32_t pixel_val = ((uint32_t *)IMAGE_BASE)[word_index] >> (byte_offset * 8);
        pixel_val &= 0xFF;
        
        *ACCEL_PIX_IN = pixel_val;
        asm volatile("nop"); asm volatile("nop"); asm volatile("nop");
    }

    // PHASE 2: VALID IMAGE 
    for (i = WARMUP_PIXELS; i < TOTAL_PIXELS; i++) {
        int word_index = i >> 2; 
        int byte_offset = i & 3; 
        uint32_t pixel_val = ((uint32_t *)IMAGE_BASE)[word_index] >> (byte_offset * 8);
        pixel_val &= 0xFF;
        
        *ACCEL_PIX_IN = pixel_val;
        asm volatile("nop"); asm volatile("nop"); asm volatile("nop");

        final_pixel = *ACCEL_MAC_OUT;
        
        while ((*UART_TX_STAT & 0x01) == 1) { asm volatile("nop"); }
        *UART_TX_DATA = final_pixel;
    }

    // PHASE 3: FLUSH REMAINDER 
    for (i = 0; i < WARMUP_PIXELS; i++) {
        *ACCEL_PIX_IN = 0; 
        asm volatile("nop"); asm volatile("nop"); asm volatile("nop");

        final_pixel = *ACCEL_MAC_OUT;
        
        while ((*UART_TX_STAT & 0x01) == 1) { asm volatile("nop"); }
        *UART_TX_DATA = final_pixel;
    }

    // Trap CPU
    while(1); 
    return 0;
}