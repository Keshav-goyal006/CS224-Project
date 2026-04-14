#include <stdint.h>
#include "image_data.h"

// ---------------------------------------------------------
// NEW 64KB Memory Map Addresses
// ---------------------------------------------------------
// Accelerator Base is 0x00012000
volatile uint32_t* const ACCEL_PIX_IN  = (uint32_t*)0x00012024; 
// volatile uint32_t* const ACCEL_TEMP = (uint32_t*)0x00012028; 
volatile uint32_t* const ACCEL_MAC_OUT = (uint32_t*)0x00012028;

// UART Base is 0x00015000
volatile uint32_t* const UART_TX_DATA  = (uint32_t*)0x00015000;
volatile uint32_t* const UART_TX_STAT  = (uint32_t*)0x00015004;

// ---------------------------------------------------------
// 256x192 Image Constants
// ---------------------------------------------------------
#define TOTAL_PIXELS 49152

// For a 5x5 kernel, warmup is usually 2 full rows + 2 pixels
// (2 * 256) + 2 = 514 pixels. 
// Adjust this if your line buffer architecture differs!
#define WARMUP_PIXELS 1028 

int main() {
    register int i asm("s1");
    register uint32_t final_pixel asm("s4");
    
    // THE BYPASS: Treat the 8-bit array as a 32-bit word array
    // This prevents the CPU from trying to execute a faulty 'lbu' byte-load
    uint32_t* words_array = (uint32_t*)image_pixels;

    // PHASE 1: WARM UP 
    for (i = 0; i < WARMUP_PIXELS; i++) {
        int word_index = i >> 2; 
        int byte_offset = i & 3; 
        uint32_t pixel_val = (words_array[word_index] >> (byte_offset * 8)) & 0xFF;
        
        *ACCEL_PIX_IN = pixel_val;
        asm volatile("nop"); asm volatile("nop"); asm volatile("nop");
    }

    // PHASE 2: VALID IMAGE 
    for (i = WARMUP_PIXELS; i < TOTAL_PIXELS; i++) {
        int word_index = i >> 2; 
        int byte_offset = i & 3; 
        uint32_t pixel_val = (words_array[word_index] >> (byte_offset * 8)) & 0xFF;
        
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