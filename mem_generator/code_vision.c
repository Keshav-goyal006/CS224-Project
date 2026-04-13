#include <stdint.h>

volatile int32_t* const ACCEL_WEIGHTS = (int32_t*)0x00002000;
volatile int32_t* const ACCEL_PIXELS  = (int32_t*)0x00002080;
volatile int32_t* const ACCEL_RESULT  = (int32_t*)0x000020F0;
volatile int32_t* const SIM_OUT_TRAP  = (int32_t*)0x00004000;

int32_t edge_kernel[9] = {-1, -1, -1, -1, 8, -1, -1, -1, -1};
// int32_t sample_pixels[9] = {10, 10, 10, 10, 50, 10, 10, 10, 10};
int32_t sample_pixels[16] = {
    10, 10, 10, 10,
    10, 50, 50, 10,
    10, 50, 50, 10,
    10, 10, 10, 10
};

int main() {
    int i;
    int32_t temp;

    // 1. Load weights with pipeline breathing room
    for (i = 0; i < 9; i++) {
        temp = edge_kernel[i];
        
        // Force the CPU to wait 2 clock cycles before using 'temp'
        asm volatile("nop");
        asm volatile("nop");
        
        ACCEL_WEIGHTS[i] = temp;
    }

    // 2. Load pixels with pipeline breathing room
    for (i = 0; i < 9; i++) {
        temp = sample_pixels[i];
        
        asm volatile("nop");
        asm volatile("nop");
        
        ACCEL_PIXELS[i] = temp;
    }

    // Give the final MAC calculation a cycle to finish
    asm volatile("nop");
    
    // 3. Read result and trap
    int32_t final_pixel = *ACCEL_RESULT;
    asm volatile("nop");
    *SIM_OUT_TRAP = final_pixel;

    return 0;
}