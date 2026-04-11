#include <stdint.h>

// --- Hardware Memory Map ---
volatile int32_t* const UART_TX_DATA = (int32_t*)0x00005000;
volatile int32_t* const UART_TX_STAT = (int32_t*)0x00005004;

// Helper to send a single character safely
void uart_send_char(char c) {
    // Wait until the UART hardware is NOT busy (Bit 0 == 0)
    // The nops prevent Load-Use hazards in your pipeline
    while ((*UART_TX_STAT & 0x01) == 1) {
        asm volatile("nop"); asm volatile("nop");
    }
    
    // Send the character
    *UART_TX_DATA = c;
    
    // Give the hardware 1 cycle to raise the "Busy" flag 
    asm volatile("nop");
}

// Helper to send a full string
void uart_send_string(const char* str) {
    // Loop until we hit the null terminator '\0'
    // Because 'str' is a char pointer, GCC will automatically 
    // use your newly fixed LBU instruction here!
    while (*str != '\0') {
        uart_send_char(*str);
        str++;
    }
}

int main() {
    // Send the victory message!
    uart_send_string("\n==============================\n");
    uart_send_string("Hello from Custom RISC-V SoC!\n");
    uart_send_string("Hardware LBU Support: ONLINE.\n");
    uart_send_string("==============================\n");

    // Loop the alphabet forever to prove stability
    char letter = 'A';
    while(1) {
        uart_send_char(letter);
        letter++;
        
        // Reset back to 'A' and print a newline after 'Z'
        if (letter > 'Z') {
            letter = 'A';
            uart_send_char('\n');
        }
    }

    return 0;
}