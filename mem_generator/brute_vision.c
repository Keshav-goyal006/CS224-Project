#include <stdint.h>

// Accelerators & TX
volatile uint32_t* const ACCEL_PIX_IN  = (uint32_t*)0x00002024; 
volatile uint32_t* const ACCEL_MAC_OUT = (uint32_t*)0x00002028; 
volatile uint32_t* const UART_TX_DATA  = (uint32_t*)0x00005000;
volatile uint32_t* const UART_TX_STAT  = (uint32_t*)0x00005004;

// NEW: UART RX
volatile uint32_t* const UART_RX_DATA  = (uint32_t*)0x00005008;
volatile uint32_t* const UART_RX_STAT  = (uint32_t*)0x0000500C;

// Global array in DMEM to hold the downloaded image (3072 bytes / 4 = 768 words)
uint32_t image_buffer[768];

int main() {
    register int i asm("s1");
    uint32_t final_pixel;
    
    // ---------------------------------------------------------
    // BOOTLOADER: WAIT FOR THE IMAGE OVER UART
    // ---------------------------------------------------------
    for (i = 0; i < 768; i++) {
        uint32_t packed_word = 0;
        
        // Receive 4 bytes to make 1 word
        for (int b = 0; b < 4; b++) {
            // Wait for RX Status flag to go high (1)
            while ((*UART_RX_STAT & 0x01) == 0) { asm volatile("nop"); }
            
            // Read the byte (This automatically clears the RX STAT flag)
            uint8_t received_byte = (uint8_t)(*UART_RX_DATA);
            
            // Shift it into the correct position in the 32-bit word
            packed_word |= (received_byte << (b * 8));
        }
        
        // Save the perfectly packed 32-bit word into Data Memory
        image_buffer[i] = packed_word;
    }

    // ---------------------------------------------------------
    // EXECUTION: PROCESS THE IMAGE
    // ---------------------------------------------------------
    // The rest of your exact same code goes here!
    // Just use image_buffer instead of image_buffer.
    
    for (i = 0; i < 130; i++) {
        int word_index = i >> 2; 
        int byte_offset = i & 3; 
        uint32_t pixel_val = (image_buffer[word_index] >> (byte_offset * 8)) & 0xFF;
        
        *ACCEL_PIX_IN = pixel_val;
        asm volatile("nop"); asm volatile("nop"); asm volatile("nop");
    }
    
    
    // ---------------------------------------------------------
    // PHASE 2: PROCESS THE VALID IMAGE
    // Push the remaining pixels, read the valid results, and transmit!
    // ---------------------------------------------------------
    for (i = 130; i < 3072; i++) {
        int word_index = i >> 2; 
        int byte_offset = i & 3; 
        uint32_t pixel_val = (image_buffer[word_index] >> (byte_offset * 8)) & 0xFF;
        
        *ACCEL_PIX_IN = pixel_val;
        asm volatile("nop"); asm volatile("nop"); asm volatile("nop");

        final_pixel = *ACCEL_MAC_OUT;
        
        while ((*UART_TX_STAT & 0x01) == 1) { asm volatile("nop"); }
        *UART_TX_DATA = final_pixel;
    }

    // ---------------------------------------------------------
    // PHASE 3: FLUSH THE REMAINDER
    // Push 130 dummy pixels (0) to force the last rows out of the FIFOs.
    // (Total transmitted pixels: (3072 - 130) + 130 = exactly 3072!)
    // ---------------------------------------------------------
    for (i = 0; i < 130; i++) {
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