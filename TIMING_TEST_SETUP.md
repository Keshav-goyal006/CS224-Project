# Stream Accelerator 5x5 RGB Timing Test - Setup Complete

## Summary of Changes

I've successfully created a complete timing analysis testbench for the stream accelerator with a 9x9 RGB image. Here's what was implemented:

## Created Files

### 1. Core Testbench
- **[modules/tb_stream_accel_5x5_rgb_timing.v](../modules/tb_stream_accel_5x5_rgb_timing.v)**
  - Instantiates `stream_accel_5x5_rgb` module with 9x9 image
  - Generates gradient RGB test pattern (R increases top→bottom, G increases left→right, B constant)
  - Streams 81 pixels + 5 flush cycles
  - Logs all cycle-by-cycle outputs with status (WARMUP/VALID/FLUSH)
  - Output file: `stream_accel_timing_log.txt`

### 2. Test Code for imem/dmem Generation
- **[mem_generator/code_rgb_vision_9x9.c](../mem_generator/code_rgb_vision_9x9.c)**
  - Modified version of code_rgb_vision.c for 9x9 images
  - Streams pixels into accelerator at 100MHz
  - Reads filtered output and sends via UART
  - Dimensions: IMG_WIDTH=9, IMG_HEIGHT=9, TOTAL_PIXELS=81

### 3. Image Generation Utilities
- **[mem_generator/generate_9x9_image.py](../mem_generator/generate_9x9_image.py)**
  - Creates 9x9 PNG test image with gradient patterns
  - Generates `image_data_9x9_rgb.h` C header file
  - Each pixel: R=(row×32), G=(col×32), B=128
  - Output: `test_9x9_rgb.png`

- **[sim/gen_9x9_bootloader_input.py](../sim/gen_9x9_bootloader_input.py)**
  - Converts image header to bootloader input bytes
  - Parses image_data_9x9_rgb.h and generates RGB bytes
  - Output: `image_9x9_rgb_bytes.txt`

### 4. Build System Updates
- **[mem_generator/Makefile](../mem_generator/Makefile)**
  - Added `timing_9x9` target for compiling 9x9 test
  - Added `generate_9x9_image` target
  - Updated clean target to remove 9x9 files

- **[sim/Makefile](../sim/Makefile)**
  - Added `timing_9x9` target for running simulation
  - Command: `make timing_9x9` (one-shot build + test)
  - Automatically generates image, compiles, and runs simulation

### 5. Analysis Tools
- **[sim/parse_timing_log.py](../sim/parse_timing_log.py)**
  - Parses `stream_accel_timing_log.txt`
  - Generates summary statistics
  - Creates markdown timing table
  - Creates VCD-like waveform representation

### 6. Documentation
- **[docs/TIMING_TESTBENCH_README.md](../docs/TIMING_TESTBENCH_README.md)**
  - Complete guide to using the timing testbench
  - Expected behavior during warmup and valid phases
  - Kernel configuration options
  - Timing analysis details
  - Modification instructions

## Quick Start

### Run the Timing Test
```bash
cd sim
make timing_9x9
```

This single command will:
1. Generate 9x9 test image (test_9x9_rgb.png, image_data_9x9_rgb.h)
2. Create bootloader input file
3. Compile bootloader + code_rgb_vision_9x9.c with RISC-V tools
4. Generate imem.hex and dmem.hex
5. Run Vivado simulation (xvlog, xelab, xsim)
6. Output timing log: `stream_accel_timing_log.txt`

### Analyze Results
```bash
cd sim
python parse_timing_log.py
```

This generates:
- Summary statistics
- Markdown table (timing_table.md)
- Waveform representation (timing_waveform.txt)

## Test Flow

### Image: 9x9 RGB Gradient
```
Pixel(row,col) = (R=row×32, G=col×32, B=128)

       Col0    Col1    Col2  ...  Col8
Row0: (  0,   0, 128) (  0,  32, 128) ... (  0, 224, 128)
Row1: ( 32,   0, 128) ( 32,  32, 128) ... ( 32, 224, 128)
...
Row8: (224,   0, 128) (224,  32, 128) ... (224, 224, 128)
```

### Timing
- **Per Pixel**: 2 clock cycles (100MHz = 10ns)
  - Cycle N: Push pixel (we=1, waddr=0x12024)
  - Cycle N+1: Read output (we=0, raddr=0x12028)
- **Total Test**: ~170 cycles (81 pixels + 5 flush)

### Window Processing
- **Warmup Phase**: Pixels 0-20 (line buffers filling)
- **Valid Phase**: Pixels 21-80 (full 5x5 window available)
- **Flush Phase**: Pixels 81-85 (drain pipeline with zeros)

### Output Format
Each line in timing log:
```
CYCLE | INPUT_HEX | R=val G=val B=val | OUTPUT_HEX | STATUS
45    | 00a08080  | R=160 G=128 B=128 | 00a2809f   | VALID
```

## Module Architecture

```
┌─────────────────────────────────────────────┐
│     stream_accel_5x5_rgb                    │
│  (IMG_WIDTH = 9)                            │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  4 Line Buffers (24-bit each)       │   │
│  │  LB1 → LB2 → LB3 → LB4             │   │
│  └─────────────────────────────────────┘   │
│              ↓                              │
│  ┌─────────────────────────────────────┐   │
│  │  5x5 Pixel Window (24-bit pixels)   │   │
│  │  w[0:4][0:4] = 5x5 = 25 pixels      │   │
│  └─────────────────────────────────────┘   │
│              ↓                              │
│  ┌─────────────────────────────────────┐   │
│  │  Kernel Selection (switches)        │   │
│  │  0001: Gaussian Blur (default)      │   │
│  │  0010: Edge Detection               │   │
│  │  0100: Sharpen                      │   │
│  │  ... (8 kernels total)              │   │
│  └─────────────────────────────────────┘   │
│              ↓                              │
│  ┌─────────────────────────────────────┐   │
│  │  MAC + Shift Result                 │   │
│  │  Output = Convolution / 2^shift     │   │
│  └─────────────────────────────────────┘   │
│              ↓                              │
│  Output Register (32-bit RGB)               │
│  Accessible at raddr = 0x12028              │
│                                             │
└─────────────────────────────────────────────┘
```

## File Dependencies

```
mem_generator/
  code_rgb_vision_9x9.c ← (uses) crt0.s, link.ld, bootloader.c
  generate_9x9_image.py → test_9x9_rgb.png
  generate_9x9_image.py → image_data_9x9_rgb.h

sim/
  gen_9x9_bootloader_input.py ← (reads) image_data_9x9_rgb.h
  parse_timing_log.py ← (reads) stream_accel_timing_log.txt

modules/
  tb_stream_accel_5x5_rgb_timing.v ← (instantiates) stream_accel_5x5_rgb
  tb_stream_accel_5x5_rgb_timing.v → stream_accel_timing_log.txt
```

## Kernel Modes

Testbench uses switch signals to select filters:

| Switch | Kernel | Purpose |
|--------|--------|---------|
| 0001 | Gaussian Blur | Smoothing (default) |
| 0010 | Edge Detection | Gradient detection |
| 0100 | Sharpen | Enhancement |
| 0011 | Diagonal Motion Blur | Motion effect |
| 0101 | Unsharp Mask | High-contrast sharpen |
| 0110 | Vertical Sobel | Vertical edge detection |
| 0111 | Cross Flare | Plus-shaped flare |
| 1000 | Morphological | Min-tree operation |

## Output Interpretation

### Valid Pixel (After Warmup)
```
Input: 9x9 image pixel
       ↓ (push to accelerator)
       ... (2-3 pipeline stages)
       ↓
Output: Gaussian-blurred result
        (0x00RRGGBB format)
```

### Gaussian Blur Calculation
For a 5x5 window with kernel:
```
 1  4  6  4  1
 4 16 24 16  4
 6 24 36 24  6
 4 16 24 16  4
 1  4  6  4  1
─────────────────── (sum = 256)
```

Output = (sum of weighted pixels) / 256

Example: 9x9 test pattern will show:
- Corners: Low values (dark region)
- Center: High values (bright region after blur)
- Edges: Gradual transitions

## Next Steps

1. **Run timing test**: `make timing_9x9`
2. **View log**: `cat stream_accel_timing_log.txt` or `less stream_accel_timing_log.txt`
3. **Analyze**: `python parse_timing_log.py`
4. **Create diagram**: Use timing_table.md output in documentation
5. **Modify kernel**: Change `switches` in testbench for different filters
6. **Change image size**: Modify IMG_WIDTH/IMG_HEIGHT in code_rgb_vision_9x9.c

## Troubleshooting

### "image_data_9x9_rgb.h not found"
→ Run `make timing_9x9` (full target rebuilds everything)

### "RISC-V compiler not found"
→ Install: `riscv-none-elf-gcc` (check PATH)

### "xvlog: command not found"
→ Vivado simulation tools not in PATH. Ensure Vivado is sourced in your shell.

### Timing log is empty
→ Check `stdout` in sim/ for simulation errors
→ Check `xvlog.log`, `xelab.log` for compilation issues

## References

- Testbench documentation: [TIMING_TESTBENCH_README.md](../docs/TIMING_TESTBENCH_README.md)
- Stream accelerator module: [stream_accel_5x5_rgb.v](../modules/stream_accel_5x5_rgb.v)
- RGB vision code: [code_rgb_vision.c](../mem_generator/code_rgb_vision.c)
- Bootloader: [bootloader.c](../mem_generator/bootloader.c)
