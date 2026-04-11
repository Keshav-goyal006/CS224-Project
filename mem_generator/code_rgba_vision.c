#include <stdint.h>
#include "image_data_rgba.h" // Includes our 64x48 RGB C-array (9,216 bytes)

// =====================================================================
// HARDWARE MEMORY MAP (Expanded 64KB Architecture)
// =====================================================================
// Notice the '2' instead of the '0'!
volatile int32_t* const ACCEL_WEIGHTS = (int32_t*)0x00020000;
volatile int32_t* const ACCEL_PIXELS  = (int32_t*)0x00020040;
volatile int32_t* const ACCEL_RESULT  = (int32_t*)0x00020080;
volatile int32_t* const UART_TX_DATA  = (int32_t*)0x00023000;
volatile int32_t* const UART_TX_STAT  = (int32_t*)0x00023004;

// =====================================================================
// KERNEL LIBRARY
// =====================================================================
// 1. Box Blur (Requires shift_amount = 3)
int32_t kernel_blur[9]    = { 1,  1,  1, 
                              1,  1,  1, 
                              1,  1,  1};

// 2. Edge Detect (Requires shift_amount = 0, uses absolute value)
int32_t kernel_edge[9]    = {-1, -1, -1, 
                             -1,  8, -1, 
                             -1, -1, -1};

// 3. Sharpen (Requires shift_amount = 0)
int32_t kernel_sharpen[9] = { 0, -1,  0, 
                             -1,  5, -1, 
                              0, -1,  0};

// =====================================================================
// ACTIVE CONFIGURATION
// =====================================================================
// Change these two variables to try different filters!
int32_t* current_kernel = kernel_blur; 
int shift_amount        = 3; // Use 3 for Blur. Use 0 for Edge/Sharpen.

int main() {
    register int row asm("s1");
    register int col asm("s2");
    register int i, j, k asm("s3");
    register int32_t temp_pixel asm("s4");
    register int32_t raw_mac    asm("s5");
    
    // ---------------------------------------------------------
    // 1. LOAD WEIGHTS INTO HARDWARE ACCELERATOR
    // ---------------------------------------------------------
    for (k = 0; k < 9; k++) {
        ACCEL_WEIGHTS[k] = current_kernel[k]; 
        asm volatile("nop"); asm volatile("nop");
    }

    // ---------------------------------------------------------
    // 2. SLIDING WINDOW: PROCESS 64x48 RGB IMAGE
    // ---------------------------------------------------------
    for (row = 0; row < 48; row++) {
        for (col = 0; col < 64; col++) {
            
            // Loop through the 3 color channels (0=Red, 1=Green, 2=Blue)
            for (int channel = 0; channel < 3; channel++) {
                
                k = 0; // Reset hardware pixel array index
                
                // Loop through the 3x3 neighbor window
                for (i = -1; i <= 1; i++) {
                    for (j = -1; j <= 1; j++) {
                        
                        int target_row = row + i;
                        int target_col = col + j;
                        int pixel_val = 0; // Default to black padding for edges
                        
                        // Boundary Check: Ensure we don't read outside the image array
                        if (target_row >= 0 && target_row < 48 && target_col >= 0 && target_col < 64) {
                            
                            // RGB Math: 
                            // Multiply by width (64), then multiply by 3 (because 3 bytes per pixel)
                            // Finally, add the specific color channel offset (0, 1, or 2)
                            int base_index = ((target_row * 64) + target_col) * 3;
                            pixel_val = image_pixels[base_index + channel];
                        }

                        // Feed pixel to hardware MAC
                        ACCEL_PIXELS[k] = pixel_val;
                        k++;
                        asm volatile("nop"); asm volatile("nop");
                    }
                }
                
                // Give accelerator time to finish final addition
                asm volatile("nop"); asm volatile("nop"); 
                
                // ---------------------------------------------------------
                // 3. RETRIEVE RESULT & SCALE
                // ---------------------------------------------------------
                raw_mac = *ACCEL_RESULT; 
                asm volatile("nop"); asm volatile("nop"); asm volatile("nop"); 
                
                // Shift down (Divide) based on our active configuration
                temp_pixel = raw_mac >> shift_amount;
                
                // Absolute value logic (Crucial for Edge Detection!)
                if (temp_pixel < 0) {
                    temp_pixel = -temp_pixel; 
                }
                
                // Saturation: Clamp to 0-255 (Color byte limits)
                if (temp_pixel > 255) {
                    temp_pixel = 255;
                }
                
                // ---------------------------------------------------------
                // 4. TRANSMIT BYTE VIA UART
                // ---------------------------------------------------------
                // Wait for UART to not be busy
                while ((*UART_TX_STAT & 0x01) == 1) { 
                    asm volatile("nop"); 
                }
                
                // Send the specific color channel byte!
                *UART_TX_DATA = temp_pixel;
                asm volatile("nop");
                
            } // End of Color Channel Loop
        }
    }

    // End of program: Trap CPU in infinite loop
    while(1); 
    
    return 0;
}