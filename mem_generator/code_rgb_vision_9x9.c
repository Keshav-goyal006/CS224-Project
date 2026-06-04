#include <stdint.h>

// 1. The Naked Bootloader
void __attribute__((naked)) bootloader_main(void) {
    asm volatile ("ret"); 
}

// 2. The Burst Core with Final Read
void __attribute__((naked)) main(void) {
    
    asm volatile (
        // --- MEMORY MAP SETUP ---
        "li x10, 0x00012024 \n\t"  // x10 = ACCEL_PUSH_ADDR
        "li x27, 0x00012028 \n\t"  // x27 = ACCEL_READ_ADDR (NEW)
        
        // --- PIXEL DATA SETUP ---
        "li x11, 0x00000000 \n\t" // P1 (Black)
        "li x12, 0x00000000 \n\t" // P2
        "li x13, 0x00000000 \n\t" // P3
        "li x14, 0x00000000 \n\t" // P4
        "li x15, 0x00000000 \n\t" // P5
        "li x16, 0x00FFFFFF \n\t" // P6 (White Edge)
        "li x17, 0x00FFFFFF \n\t" // P7
        "li x18, 0x00FFFFFF \n\t" // P8
        "li x19, 0x00FFFFFF \n\t" // P9
        "li x20, 0x00FFFFFF \n\t" // P10
        "li x21, 0x00FF0000 \n\t" // P11 (Red)
        "li x22, 0x0000FF00 \n\t" // P12 (Green)
        "li x23, 0x000000FF \n\t" // P13 (Blue)
        "li x24, 0x00888888 \n\t" // P14 (Gray)
        "li x25, 0x00123456 \n\t" // P15 (Mix)
        
        // --- BURST PHASE: 15 Pushes ---
        "sw x11, 0(x10) \n\t"
        "sw x12, 0(x10) \n\t"
        "sw x13, 0(x10) \n\t"
        "sw x14, 0(x10) \n\t"
        "sw x15, 0(x10) \n\t"
        "sw x16, 0(x10) \n\t"
        "sw x17, 0(x10) \n\t"
        "sw x18, 0(x10) \n\t"
        "sw x19, 0(x10) \n\t"
        "sw x20, 0(x10) \n\t"
        "sw x21, 0(x10) \n\t"
        "sw x22, 0(x10) \n\t"
        "sw x23, 0(x10) \n\t"
        "sw x24, 0(x10) \n\t"
        "sw x25, 0(x10) \n\t"
        
        // --- FLUSH PHASE: 20 Dummy Zeroes ---
        "li x11, 0x00000000 \n\t"
        "sw x11, 0(x10) \n\t" "sw x11, 0(x10) \n\t" "sw x11, 0(x10) \n\t"
        "sw x11, 0(x10) \n\t" "sw x11, 0(x10) \n\t" "sw x11, 0(x10) \n\t"
        "sw x11, 0(x10) \n\t" "sw x11, 0(x10) \n\t" "sw x11, 0(x10) \n\t"
        "sw x11, 0(x10) \n\t" "sw x11, 0(x10) \n\t" "sw x11, 0(x10) \n\t"
        "sw x11, 0(x10) \n\t" "sw x11, 0(x10) \n\t" "sw x11, 0(x10) \n\t"
        "sw x11, 0(x10) \n\t" "sw x11, 0(x10) \n\t" "sw x11, 0(x10) \n\t"
        "sw x11, 0(x10) \n\t" "sw x11, 0(x10) \n\t"

        // --- SINGLE READ (NEW) ---
        // Load Word (lw) from the Accelerator Read Address into register x26
        "lw x26, 0(x27) \n\t"

        // --- TRAP ---
        "infinite_trap: j infinite_trap \n\t"
    );
}