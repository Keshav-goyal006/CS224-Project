#include <stdint.h>
#include "image_data.h" // Includes our 19,200 pixel array!

volatile int32_t* const ACCEL_WEIGHTS = (int32_t*)0x00002000;
volatile int32_t* const ACCEL_PIXELS  = (int32_t*)0x00002040;
volatile int32_t* const ACCEL_RESULT  = (int32_t*)0x00002080;
volatile int32_t* const UART_TX_DATA  = (int32_t*)0x00005000;
volatile int32_t* const UART_TX_STAT  = (int32_t*)0x00005004;

// CHOOSE YOUR KERNEL HERE
int32_t current_kernel[9] = {1,1,1,1,1,1,1,1,1};
// {-1,-1,-1,-1,8,-1,-1,-1,-1}; // Edge Detect

int main() {
    register int row asm("s1");
    register int col asm("s2");
    register int i, j, k asm("s3");
    register int32_t temp_pixel asm("s4");
    register int32_t raw_mac    asm("s5");
    
    // 1. Load weights into the accelerator
    for (k = 0; k < 9; k++) {
        ACCEL_WEIGHTS[k] = current_kernel[k]; 
        asm volatile("nop"); asm volatile("nop");
    }

    // 2. Process Image with a 3x3 Sliding Window
    for (row = 0; row < 48; row++) {
        for (col = 0; col < 64; col++) {
            
            k = 0;
            
            for (i = -1; i <= 1; i++) {
                for (j = -1; j <= 1; j++) {
                    
                    int target_row = row + i;
                    int target_col = col + j;
                    int pixel_val = 0; 
                    
                    // Boundary check updated for 64x48
                    if (target_row >= 0 && target_row < 48 && target_col >= 0 && target_col < 64) {
                        // 2D to 1D array math updated (Multiply by width: 64)
                        pixel_val = image_pixels[(target_row * 64) + target_col];
                    }


                    ACCEL_PIXELS[k] = pixel_val;
                    k++;
                    asm volatile("nop"); asm volatile("nop");
                }
            }
            
            asm volatile("nop"); asm volatile("nop"); 
            
            // 3. Get Result
            raw_mac = *ACCEL_RESULT; 
            asm volatile("nop"); asm volatile("nop"); asm volatile("nop"); 
            
            // 4. Scale Result (Adjust bit-shift based on your chosen kernel!)
            // For Edge Detect / Sharpen: use >> 0
            // For Box Blur: use >> 3
            // temp_pixel = raw_mac >> 3;
            temp_pixel = raw_mac >> 3;
            
            // Saturate to keep it between 0 and 255 (Black and White)
            // Absolute value logic: Edge detection can produce negative math, we want the absolute edge magnitude.
            if (temp_pixel < 0) temp_pixel = -temp_pixel; 
            if (temp_pixel > 255) temp_pixel = 255;
            
            // 5. Transmit
            while ((*UART_TX_STAT & 0x01) == 1) { asm volatile("nop"); }
            *UART_TX_DATA = temp_pixel;
            asm volatile("nop");
        }
    }

    while(1); 
    return 0;
}