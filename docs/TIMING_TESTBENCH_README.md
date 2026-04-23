# Stream Accelerator 5x5 RGB Timing Testbench

This testbench is designed to analyze and visualize the cycle-by-cycle operation of the `stream_accel_5x5_rgb` module with a small 9x9 RGB test image.

## Overview

- **Testbench File**: `modules/tb_stream_accel_5x5_rgb_timing.v`
- **Image Size**: 9x9 pixels (81 total pixels)
- **Kernel**: 5x5 Gaussian Blur (configurable via switches)
- **Window Size**: 5x5 pixels
- **Warmup Pixels**: (2 × IMG_WIDTH) + 3 = 21 pixels
- **Valid Output Pixels**: 81 - 21 = 60 pixels

## Files Structure

### Core Components

1. **Testbench**: `modules/tb_stream_accel_5x5_rgb_timing.v`
   - Instantiates `stream_accel_5x5_rgb` with 9x9 image width
   - Generates test pixel data (gradient RGB pattern)
   - Streams pixels at 100MHz clock frequency
   - Logs all cycle-by-cycle outputs to `stream_accel_timing_log.txt`

2. **Test Code**: `mem_generator/code_rgb_vision_9x9.c`
   - Modified version of `code_rgb_vision.c` for 9x9 images
   - Configures system for small test image processing
   - Used for imem/dmem generation

3. **Image Generator**: `mem_generator/generate_9x9_image.py`
   - Creates a 9x9 PNG test image with gradient patterns
   - Generates C header file with pixel data
   - Pattern: Red increases top→bottom, Green increases left→right, Blue constant

4. **Bootloader Input Generator**: `sim/gen_9x9_bootloader_input.py`
   - Converts image header to bootloader input format
   - Generates `image_9x9_rgb_bytes.txt` for simulation

## Running the Timing Test

### Quick Start

```bash
cd sim
make timing_9x9
```

This command will:
1. Generate the 9x9 test image and image header
2. Compile bootloader + code_rgb_vision_9x9.c → imem/dmem hex files
3. Compile testbench with xvlog
4. Elaborate design with xelab
5. Run simulation with xsim
6. Generate `stream_accel_timing_log.txt`

### Output Files

After running the test, you'll find:

- **`stream_accel_timing_log.txt`**: Cycle-by-cycle timing log with:
  - Cycle number
  - Input pixel data (R, G, B components)
  - Output RGB value from accelerator
  - Window validity status (WARMUP or VALID)

- **`test_9x9_rgb.png`**: Visual representation of the 9x9 test image

- **`image_data_9x9_rgb.h`**: C header file with pixel values

## Test Image Pattern

The generated 9x9 test image uses a gradient pattern:

```
       Col0  Col1  Col2  Col3  Col4  Col5  Col6  Col7  Col8
Row0:  (  0,   0, 128) (  0,  32, 128) (  0,  64, 128) ...
Row1:  ( 32,   0, 128) ( 32,  32, 128) ( 32,  64, 128) ...
Row2:  ( 64,   0, 128) ( 64,  32, 128) ( 64,  64, 128) ...
...
```

This pattern makes it easy to verify filter operations visually.

## Expected Behavior

### Warmup Phase (Pixels 0-20)

During the first 21 pixels:
- Line buffers are being filled
- 5x5 window is not yet complete
- Output is mostly zeros or partial convolution results

### Valid Output Phase (Pixels 21-80)

After warmup:
- All 5 line buffers contain valid data
- Full 5x5 window is available
- Gaussian blur kernel is applied to each window
- Output is valid filtered pixel data

### Output Calculation

For each valid 5x5 window:
```
Output[i] = (Blur Kernel) ⊗ (5x5 Window) / 256
```

Gaussian Blur Kernel:
```
 1  4  6  4  1
 4 16 24 16  4
 6 24 36 24  6
 4 16 24 16  4
 1  4  6  4  1
```
Sum = 256 (normalized)

## Timing Analysis

### Clock Cycles

- **Per Pixel**: 2 clock cycles
  - Cycle 1: Write pixel to ACCEL_PUSH
  - Cycle 2: Read result from ACCEL_READ
- **Total Test Cycles**: ~170 cycles (for 81 pixels + 5 flush pixels)

### Access Pattern

```
Cycle    Operation
------   -------------------
N        Push Pixel (we=1, waddr=0x12024)
N+1      Read Output (we=0, raddr=0x12028)
N+2      Push Pixel
N+3      Read Output
...
```

## Kernel Configuration

The testbench uses switch signals to select different kernels:

- `switches = 4'b0001`: Gaussian Blur (default for timing test)
- `switches = 4'b0010`: Edge Detection
- `switches = 4'b0100`: Sharpen
- `switches = 4'b0011`: Diagonal Motion Blur
- `switches = 4'b0101`: Unsharp Mask
- `switches = 4'b0110`: Vertical Sobel
- `switches = 4'b0111`: Cross Flare

## Modifying the Test

### Change Image Size

Edit `code_rgb_vision_9x9.c`:
```c
enum {
    IMG_WIDTH = 9,      // Change to desired width
    IMG_HEIGHT = 9,     // Change to desired height
    ...
};
```

### Change Kernel

Edit `tb_stream_accel_5x5_rgb_timing.v`:
```v
switches = 4'b0010;  // Change to different kernel
```

### Change Test Pattern

Edit `generate_9x9_image.py` to create different gradient patterns.

## Troubleshooting

### Image file not found
```
Error: file not found: test_9x9_rgb.png
```
Solution: Run `make timing_9x9` which calls `generate_9x9_image.py`

### Hex file generation fails
Check that RISC-V tools are installed:
```bash
riscv-none-elf-gcc --version
riscv-none-elf-objcopy --version
```

### Timing log not generated
Check that testbench compiled without errors. Look at:
- `xvlog.log` for compilation errors
- `xelab.log` for elaboration errors
- `stdout` for simulation output

## Creating a Timing Diagram

The output file `stream_accel_timing_log.txt` can be converted to a timing diagram using:

1. **Python/Matplotlib**: Plot output values vs. cycle number
2. **Markdown Table**: Convert to formatted table for documentation
3. **Verilog VCD**: Extract `.vcd` waveform from simulation

Example Python script to plot:
```python
import matplotlib.pyplot as plt

# Parse stream_accel_timing_log.txt
cycles = []
outputs = []
with open('stream_accel_timing_log.txt', 'r') as f:
    for line in f:
        if '|' in line and 'CYCLE' not in line:
            parts = line.split('|')
            cycles.append(int(parts[0].strip()))
            outputs.append(int(parts[3].strip(), 16))

plt.plot(cycles, outputs)
plt.xlabel('Cycle Number')
plt.ylabel('Output RGB Value')
plt.title('Stream Accelerator Timing Diagram')
plt.savefig('timing_diagram.png')
plt.show()
```

## References

- [stream_accel_5x5_rgb.v](../modules/stream_accel_5x5_rgb.v)
- [code_rgb_vision.c](code_rgb_vision.c)
- [bootloader.c](bootloader.c)
- [Timing Results](stream_accel_timing_log.txt)
