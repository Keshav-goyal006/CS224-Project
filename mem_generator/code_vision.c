// #include <stdint.h>

// // --- Hardware Memory Map ---
// // Base addresses derived from soc_interconnect logic [cite: 89-94]
// volatile int32_t* const ACCEL_WEIGHTS = (int32_t*)0x00002000;
// volatile int32_t* const ACCEL_PIXELS  = (int32_t*)0x00002040;
// volatile int32_t* const ACCEL_RESULT  = (int32_t*)0x00002080;

// volatile int32_t* const UART_TX_DATA  = (int32_t*)0x00005000;
// volatile int32_t* const UART_TX_STAT  = (int32_t*)0x00005004;

// int main() {
//     // 1. FORCE VARIABLES INTO CPU REGISTERS
//     // Avoiding the Stack (DMEM) prevents Data Hazards where the CPU reads 'i'
//     // before it finishes writing it [cite: 175-182].
//     register int row asm("s1");
//     register int col asm("s2");
//     register int i   asm("s3");
//     register int32_t temp_pixel asm("s4");
//     register int32_t raw_val    asm("s5");
//     register int32_t raw_mac    asm("s6"); // Intermediate for Load-Use safety
    
//     // 2. Load weights into the accelerator
//     for (i = 0; i < 9; i++) {
//         ACCEL_WEIGHTS[i] = 1; 
//         asm volatile("nop"); asm volatile("nop");
//     }

//     // 3. Generate and send a 160x120 image
//     for (row = 0; row < 120; row++) {
//         for (col = 0; col < 160; col++) {
            
//             raw_val = (row ^ col) * 2; 
            
//             // Feed pixels to the hardware accelerator
//             for (i = 0; i < 9; i++) {
//                 ACCEL_PIXELS[i] = raw_val; 
//                 // NOPs ensure the write reaches memory before the next loop iteration
//                 asm volatile("nop"); asm volatile("nop");
//             }
            
//             // Allow time for the Hardware Accelerator's MAC to finish
//             asm volatile("nop"); asm volatile("nop"); 
            
//             // --- CRITICAL FIX: LOAD-USE HAZARD ---
//             // Request result from accelerator [cite: 143]
//             raw_mac = *ACCEL_RESULT; 
            
//             // Your pipeline needs 3 NOPs here. Without them, temp_pixel will use 
//             // the OLD value of raw_mac (usually 0), giving a black image.
//             asm volatile("nop"); 
//             asm volatile("nop"); 
//             asm volatile("nop"); 
            
//             // Scale result (Sum of 9 pixels >> 3 is approx divide by 8)
//             temp_pixel = raw_mac >> 3;
            
//             // Saturation logic
//             if (temp_pixel > 255) temp_pixel = 255;
//             if (temp_pixel < 0)   temp_pixel = 0;
            
//             // 4. INLINE UART TRANSMISSION
//             // Check status bit 0: 1 = Busy, 0 = Ready [cite: 142]
//             while ((*UART_TX_STAT & 0x01) == 1) {
//                 asm volatile("nop");
//             }
            
//             // Write to UART DATA register [cite: 93, 144]
//             *UART_TX_DATA = (uint8_t)temp_pixel;

//             // Extra NOP to ensure the UART_TX_STAT updates before next pixel loop
//             asm volatile("nop");
//         }
//     }

//     while(1); 
//     return 0;
// }


#include <stdint.h>

// Hardware Addresses based on your soc_interconnect [cite: 89-94]
volatile int32_t* const ACCEL_WEIGHTS = (int32_t*)0x00002000;
volatile int32_t* const ACCEL_PIXELS  = (int32_t*)0x00002040;
volatile int32_t* const ACCEL_RESULT  = (int32_t*)0x00002080;
volatile int32_t* const SIM_TRAP      = (int32_t*)0x00004000;

int main() {
    // Force variables to registers to avoid DMEM pipeline hazards [cite: 175-182]
    register int i asm("s1");
    register int32_t result asm("s2");

    // 1. Load Weights (all 1s)
    for (i = 0; i < 9; i++) {
        ACCEL_WEIGHTS[i] = 1;
        asm volatile("nop"); asm volatile("nop");
    }

    // 2. Load Pixels (all 10s)
    // Expected Result: (1*10) * 9 = 90
    for (i = 0; i < 9; i++) {
        ACCEL_PIXELS[i] = 10;
        asm volatile("nop"); asm volatile("nop");
    }

    // 3. Wait for Hardware MAC to complete
    asm volatile("nop");
    asm volatile("nop");

    // 4. Read Result with Padding (Fixes Load-Use Hazard)
    result = *ACCEL_RESULT;
    asm volatile("nop"); 
    asm volatile("nop");
    asm volatile("nop");

    // 5. Send to Sim Trap (Watch this in Vivado console)
    *SIM_TRAP = result;

    while(1);
    return 0;
}