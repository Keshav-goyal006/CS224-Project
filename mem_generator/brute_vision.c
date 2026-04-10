#include <stdint.h>

volatile int32_t* const UART_TX_DATA  = (int32_t*)0x00005000;
volatile int32_t* const UART_TX_STAT  = (int32_t*)0x00005004;

int main() {
    while (1) {
        // Wait for UART to be ready
        while ((*UART_TX_STAT & 0x01) == 1) {
            asm volatile("nop");
        }
        
        // Send the letter 'A' (ASCII 65) directly from CPU registers
        *UART_TX_DATA = 65; 
    }
    return 0;
}