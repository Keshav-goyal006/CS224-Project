// #include <stdint.h>

// volatile int32_t* const ACCEL_WEIGHTS = (int32_t*)0x00002000;
// volatile int32_t* const ACCEL_PIXELS  = (int32_t*)0x00002040;
// volatile int32_t* const ACCEL_RESULT  = (int32_t*)0x00002080;
// volatile int32_t* const SIM_OUT_TRAP  = (int32_t*)0x00004000;

// int32_t edge_kernel[9] = {-1, -1, -1, -1, 8, -1, -1, -1, -1};
// // int32_t sample_pixels[9] = {10, 10, 10, 10, 50, 10, 10, 10, 10};
// int32_t sample_pixels[16] = {
//     10, 10, 10, 10,
//     10, 50, 50, 10,
//     10, 50, 50, 10,
//     10, 10, 10, 10
// };

// int main() {
//     int i;
//     int32_t temp;

//     // 1. Load weights with pipeline breathing room
//     for (i = 0; i < 9; i++) {
//         temp = edge_kernel[i];
        
//         // Force the CPU to wait 2 clock cycles before using 'temp'
//         asm volatile("nop");
//         asm volatile("nop");
        
//         ACCEL_WEIGHTS[i] = temp;
//     }

//     // 2. Load pixels with pipeline breathing room
//     for (i = 0; i < 9; i++) {
//         temp = sample_pixels[i];
        
//         asm volatile("nop");
//         asm volatile("nop");
        
//         ACCEL_PIXELS[i] = temp;
//     }

//     // Give the final MAC calculation a cycle to finish
//     asm volatile("nop");
    
//     // 3. Read result and trap
//     int32_t final_pixel = *ACCEL_RESULT;
//     asm volatile("nop");
//     *SIM_OUT_TRAP = final_pixel;

//     return 0;
// }


#include <stdint.h>

// --- Hardware Memory Map ---
volatile int32_t* const ACCEL_WEIGHTS = (int32_t*)0x00002000;
volatile int32_t* const ACCEL_PIXELS  = (int32_t*)0x00002040;
volatile int32_t* const ACCEL_RESULT  = (int32_t*)0x00002080;

// VRAM Base Address (Mapped to 0x4000XXXX in top_fpga.v)
volatile uint8_t* const VRAM = (uint8_t*)0x40000000;

int main() {
    int row, col, i;
    int32_t temp_pixel;
    
    // An Emboss kernel (Looks really cool on physical hardware!)
    int32_t kernel[9] = {-2, -1, 0,
                         -1,  1, 1,
                          0,  1, 2};
    
    // Load weights into the accelerator
    for (i = 0; i < 9; i++) {
        ACCEL_WEIGHTS[i] = kernel[i];
        asm volatile("nop"); asm volatile("nop");
    }

    // Generate and process a 160x120 image procedurally
    for (row = 0; row < 120; row++) {
        for (col = 0; col < 160; col++) {
            
            // Generate a mathematical pattern (XOR texture)
            int32_t raw_val = (row ^ col) * 2; 
            
            // Feed it to the hardware accelerator
            for (i = 0; i < 9; i++) {
                ACCEL_PIXELS[i] = raw_val;
                asm volatile("nop"); asm volatile("nop");
            }
            
            asm volatile("nop"); // Let MAC finish
            
            // Read result and add an offset (Emboss kernels usually need a +128 shift)
            temp_pixel = (*ACCEL_RESULT) + 128;
            
            // Saturate to prevent weird color overflow artifacts
            if (temp_pixel > 255) temp_pixel = 255;
            if (temp_pixel < 0)   temp_pixel = 0;
            
            // WRITE DIRECTLY TO VRAM
            // Calculates the linear index (matches dual_port_vram logic)
            int linear_index = (row * 160) + col;
            VRAM[linear_index] = (uint8_t)temp_pixel;
        }
    }

    // Halt the CPU by entering an infinite loop
    while(1) {
        asm volatile("nop");
    }

    return 0;
}
`