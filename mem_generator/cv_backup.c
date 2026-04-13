// Coprocessor Memory Map
#define CONV_BASE_ADDR 0x00002000
volatile int* HW_WEIGHTS = (volatile int*)(CONV_BASE_ADDR + 0x00);
volatile int* HW_PIXELS  = (volatile int*)(CONV_BASE_ADDR + 0x80);
volatile int* HW_RESULT  = (volatile int*)(CONV_BASE_ADDR + 0xF0);

// Memory-Mapped LEDs (Address 0x3000)
volatile int* FPGA_LEDS  = (volatile int*)0x00003000;

// Output of image_to_c.py goes here (Example 8x8 image):
int image[8][8] = {
    { 25,  25,  25,  25,  25,  25,  25,  25},
    { 25, 200, 200, 200, 200, 200, 200,  25},
    { 25, 200,  25,  25,  25,  25, 200,  25},
    { 25, 200,  25, 255, 255,  25, 200,  25},
    { 25, 200,  25, 255, 255,  25, 200,  25},
    { 25, 200,  25,  25,  25,  25, 200,  25},
    { 25, 200, 200, 200, 200, 200, 200,  25},
    { 25,  25,  25,  25,  25,  25,  25,  25},
};

int output_software[8][8];
int output_hardware[8][8];

// Sobel Edge Detection Kernel
int kernel[3][3] = {
    {-1, -1, -1},
    {-1,  8, -1},
    {-1, -1, -1}
};

void process_software() {
    for (int y = 1; y < 7; y++) {
        for (int x = 1; x < 7; x++) {
            int sum = 0;
            for (int ky = -1; ky <= 1; ky++) {
                for (int kx = -1; kx <= 1; kx++) {
                    sum += image[y + ky][x + kx] * kernel[ky + 1][kx + 1];
                }
            }
            output_software[y][x] = sum;
        }
    }
}

void process_hardware() {
    int max_edge = 0;

    // 1. Load weights into the accelerator ONCE
    int w_idx = 0;
    for (int ky = 0; ky < 3; ky++) {
        for (int kx = 0; kx < 3; kx++) {
            HW_WEIGHTS[w_idx++] = kernel[ky][kx];
        }
    }

    // 2. Stream pixels and process
    for (int y = 1; y < 7; y++) {
        for (int x = 1; x < 7; x++) {
            int p_idx = 0;
            for (int ky = -1; ky <= 1; ky++) {
                for (int kx = -1; kx <= 1; kx++) {
                    HW_PIXELS[p_idx++] = image[y + ky][x + kx];
                }
            }
            
            // Read result from hardware accelerator instantly
            int result = *HW_RESULT;
            output_hardware[y][x] = result;
            
            if (result > max_edge) {
                max_edge = result;
            }
        }
    }
    
    // 3. Write maximum edge detected to the physical FPGA LEDs
    *FPGA_LEDS = max_edge;
}

// Add this to your memory map at the top of the file
volatile int* SIM_FILE_OUT = (volatile int*)0x00004000;

int main() {
    process_software();
    process_hardware();
    
    // NEW: Stream the processed 8x8 image to the Verilog Testbench
    for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
            *SIM_FILE_OUT = output_hardware[y][x];
        }
    }
    

    while(1); 
    return 0;
}