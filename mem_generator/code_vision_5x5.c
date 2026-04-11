#include <stdint.h>
#include "image_data.h"

// 4KB Memory Map Addresses
volatile uint32_t* const ACCEL_PIX_IN  = (uint32_t*)0x00002024; 
volatile uint32_t* const ACCEL_MAC_OUT = (uint32_t*)0x00002028; 
volatile uint32_t* const UART_TX_DATA  = (uint32_t*)0x00005000;
volatile uint32_t* const UART_TX_STAT  = (uint32_t*)0x00005004;

int main() {
    register int i asm("s1");
    register uint32_t final_pixel asm("s4");
    
    // THE BYPASS: Treat the 8-bit array as a 32-bit word array
    // This prevents the CPU from trying to execute a faulty 'lbu' byte-load
    uint32_t* words_array = (uint32_t*)image_pixels;

    // ... setup and pointers ...

    // PHASE 1: WARM UP (258 Pixels for 5x5)
    for (i = 0; i < 258; i++) {
        int word_index = i >> 2; 
        int byte_offset = i & 3; 
        uint32_t pixel_val = (words_array[word_index] >> (byte_offset * 8)) & 0xFF;
        
        *ACCEL_PIX_IN = pixel_val;
        asm volatile("nop"); asm volatile("nop"); asm volatile("nop");
    }

    // PHASE 2: VALID IMAGE 
    for (i = 258; i < 3072; i++) {
        int word_index = i >> 2; 
        int byte_offset = i & 3; 
        uint32_t pixel_val = (words_array[word_index] >> (byte_offset * 8)) & 0xFF;
        
        *ACCEL_PIX_IN = pixel_val;
        asm volatile("nop"); asm volatile("nop"); asm volatile("nop");

        final_pixel = *ACCEL_MAC_OUT;
        
        while ((*UART_TX_STAT & 0x01) == 1) { asm volatile("nop"); }
        *UART_TX_DATA = final_pixel;
    }

    // PHASE 3: FLUSH REMAINDER (258 Dummy Pixels)
    for (i = 0; i < 258; i++) {
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