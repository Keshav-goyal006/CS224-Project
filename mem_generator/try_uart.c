#include <stdint.h>

volatile uint32_t* const UART_TX_DATA  = (uint32_t*)0x00005000;
volatile uint32_t* const UART_TX_STAT  = (uint32_t*)0x00005004;
volatile uint32_t* const UART_RX_DATA  = (uint32_t*)0x00005008;
volatile uint32_t* const UART_RX_STAT  = (uint32_t*)0x0000500C;

// THE HARDWARE DEBUGGER
volatile uint32_t* const LEDS          = (uint32_t*)0x00003000;

int main() {
    uint8_t received_byte;

    // STEP 1: Turn on the very first LED on the far right (LED[0])
    // This proves the CPU woke up and executed the first instruction!
    *LEDS = 0x0001; 

    while (1) {
        // STEP 2: Turn on the second LED (LED[1])
        // This means the CPU successfully entered the loop and is waiting for Python
        *LEDS = 0x0002; 
        
        while ((*UART_RX_STAT & 0x01) == 0) { asm volatile("nop"); }
        received_byte = (uint8_t)(*UART_RX_DATA);

        // STEP 3: Turn on the third LED (LED[2])
        // This means the CPU CAUGHT a byte from Python!
        *LEDS = 0x0004; 

        while ((*UART_TX_STAT & 0x01) == 1) { asm volatile("nop"); }
        
        // Fire it back!
        *UART_TX_DATA = received_byte;
    }
    
    return 0;
}