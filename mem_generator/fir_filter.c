// Define Memory-Mapped Addresses for the MAC Accelerator
// Based on 20'h00002 base address in pipeline.v
volatile int* MAC_REG_A = (int*)0x00002000; 
volatile int* MAC_ACC   = (int*)0x00002004; 
volatile int* MAC_RES   = (int*)0x00002008; 
volatile int* MAC_CLR   = (int*)0x0000200C; 

#define SIGNAL_LENGTH 10
#define FILTER_TAPS 4

// A simple 4-tap low-pass filter (averages the signal out)
int coeffs[FILTER_TAPS] = {1, 2, 2, 1}; 

// A "noisy" input signal with spikes
int input_signal[SIGNAL_LENGTH] = {10, 80, 12, 10, -50, 15, 12, 90, 10, 11};

// Where we will store the clean data
int output_signal[SIGNAL_LENGTH];

int main() {
    int i, j;

    // Loop through the entire audio/data signal
    for (i = 0; i < SIGNAL_LENGTH; i++) {
        
        // 1. Clear the hardware accumulator before starting a new data point
        *MAC_CLR = 1; 

        // 2. Apply the FIR Filter sliding window
        for (j = 0; j < FILTER_TAPS; j++) {
            // Ensure we don't read out of bounds (padding with 0s essentially)
            if (i - j >= 0) {
                // Write coefficient to Reg A
                *MAC_REG_A = coeffs[j];     
                
                // Write audio sample to Reg B (This also triggers the MAC multiply+add!)
                *MAC_ACC = input_signal[i - j]; 
            }
        }

        // 3. Read the final accumulated result and store it in our output array
        output_signal[i] = *MAC_RES;
    }

    // The output_signal array now contains your smoothed/filtered data!
    // For your demo, you can write these results to a memory address that 
    // your testbench prints to the console.
    
    return 0;
}