#define N 5

// Define the hardware memory addresses based on our Verilog design
volatile int* const MAC_REG_A = (int*)0x00002000;
volatile int* const MAC_REG_B = (int*)0x00002004; // Writing here triggers the MAC math!
volatile int* const MAC_ACC   = (int*)0x00002008; // Read the result from here
volatile int* const MAC_CLEAR = (int*)0x0000200C; // Write anything here to reset to 0

int A[N][N] = {{1, 2, 3, 4, 5}, {6, 7, 8, 9, 10}, {11, 12, 13, 14, 15}, {16, 17, 18, 19, 20}, {21, 22, 23, 24, 25}};
int B[N][N] = {{25, 24, 23, 22, 21}, {20, 19, 18, 17, 16}, {15, 14, 13, 12, 11}, {10, 9, 8, 7, 6}, {5, 4, 3, 2, 1}};
int C[N][N] = {0};

int main() {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            
            // 1. Tell the hardware to reset the accumulator to 0
            *MAC_CLEAR = 1; 
            
            for (int k = 0; k < N; k++) {
                // 2. Push A into the MAC
                *MAC_REG_A = A[i][k]; 
                
                // 3. Push B into the MAC. 
                // The hardware instantly does: ACC = ACC + (A * B) in exactly ONE clock cycle!
                *MAC_REG_B = B[k][j]; 
            }
            
            // 4. Read the final hardware-computed dot product and save it to normal memory
            C[i][j] = *MAC_ACC;
        }
    }

    while(1) asm volatile("nop");
    return 0;
}