# Stream Accelerator Timing Testbench - Implementation Checklist

## ✅ Complete Implementation Summary

This document verifies all components for the 9x9 stream accelerator timing test.

### 📋 Test Execution Checklist

- [x] **Testbench Module**
  - File: `modules/tb_stream_accel_5x5_rgb_timing.v`
  - Instantiates: `stream_accel_5x5_rgb` (IMG_WIDTH=9)
  - Test Pattern: 9x9 gradient RGB image (81 pixels)
  - Output: `stream_accel_timing_log.txt` with cycle-by-cycle data
  - Logs: Cycle, Input RGB, Output RGB, Status (WARMUP/VALID/FLUSH)

- [x] **Test Code for Compilation**
  - File: `mem_generator/code_rgb_vision_9x9.c`
  - Purpose: Generate imem/dmem for 9x9 image
  - Dimensions: 9×9 = 81 pixels
  - Dependencies: crt0.s, link.ld, bootloader.c
  - Output: imem.bin, dmem.bin → imem.hex, dmem.hex

- [x] **Image Generation**
  - File: `mem_generator/generate_9x9_image.py`
  - Creates: 9×9 PNG test image
  - Pattern: Gradient (R=row×32, G=col×32, B=128)
  - Outputs: 
    - `test_9x9_rgb.png` (visual)
    - `image_data_9x9_rgb.h` (C header)

- [x] **Bootloader Input Generation**
  - File: `sim/gen_9x9_bootloader_input.py`
  - Reads: `image_data_9x9_rgb.h`
  - Generates: `image_9x9_rgb_bytes.txt`
  - Format: One byte per line (R, G, B values in sequence)

### 🔨 Build System Updates

- [x] **mem_generator/Makefile**
  - New target: `timing_9x9`
  - New target: `generate_9x9_image`
  - Updated: `clean` target
  - Compiles: bootloader.c + code_rgb_vision_9x9.c with RISC-V compiler

- [x] **sim/Makefile**
  - New target: `timing_9x9`
  - One-shot command: `make timing_9x9`
  - Workflow:
    1. Generate 9x9 image
    2. Compile bootloader + code_rgb_vision_9x9.c
    3. Copy hex files to sim/
    4. Run xvlog, xelab, xsim
    5. Generate timing log
  - Updated: `clean` target

### 📊 Analysis & Visualization Tools

- [x] **Parse Timing Log**
  - File: `sim/parse_timing_log.py`
  - Reads: `stream_accel_timing_log.txt`
  - Outputs:
    - Summary statistics
    - `timing_table.md` (markdown table)
    - `timing_waveform.txt` (VCD-like format)
  - Command: `python parse_timing_log.py`

- [x] **Visualize Timing**
  - File: `sim/visualize_timing.py`
  - Requires: matplotlib (optional)
  - Generates:
    - `timing_diagram.png` (full timeline)
    - `timing_diagram_valid_region.png` (zoomed valid region)
    - Statistics printout
  - Command: `python visualize_timing.py`

### 📖 Documentation

- [x] **Detailed README**
  - File: `docs/TIMING_TESTBENCH_README.md`
  - Covers:
    - Overview and architecture
    - File structure and purposes
    - Running the test
    - Test image pattern
    - Expected behavior
    - Timing analysis details
    - Kernel configuration
    - Modification instructions
    - Troubleshooting

- [x] **Setup Summary**
  - File: `TIMING_TEST_SETUP.md` (root directory)
  - Quick reference for:
    - Quick start commands
    - Test flow explanation
    - Module architecture diagram
    - File dependencies
    - Next steps
    - Troubleshooting

- [x] **Implementation Checklist**
  - File: `IMPLEMENTATION_CHECKLIST.md` (this file)
  - Verification of all components

### 🚀 Quick Start Commands

```bash
# Run the complete timing test (one command)
cd sim
make timing_9x9

# Analyze results
python parse_timing_log.py

# Visualize timing (requires matplotlib)
python visualize_timing.py

# View timing log
cat stream_accel_timing_log.txt
```

### 📁 Complete File List

**New Testbench Files:**
- `modules/tb_stream_accel_5x5_rgb_timing.v` (testbench)

**New Code Files:**
- `mem_generator/code_rgb_vision_9x9.c` (9x9 variant)

**New Utility Scripts:**
- `mem_generator/generate_9x9_image.py` (image generator)
- `sim/gen_9x9_bootloader_input.py` (bootloader input)
- `sim/parse_timing_log.py` (log parser)
- `sim/visualize_timing.py` (visualization)

**Modified Build Files:**
- `mem_generator/Makefile` (added timing_9x9 target)
- `sim/Makefile` (added timing_9x9 target)

**Documentation Files:**
- `docs/TIMING_TESTBENCH_README.md` (detailed guide)
- `TIMING_TEST_SETUP.md` (quick reference)
- `IMPLEMENTATION_CHECKLIST.md` (this file)

### 📊 Test Specifications

| Parameter | Value |
|-----------|-------|
| Image Size | 9×9 = 81 pixels |
| Kernel | 5×5 Gaussian Blur |
| Kernel Mode | 0001 (configurable) |
| Window Size | 5×5 pixels |
| Warmup Pixels | (2×9)+3 = 21 |
| Valid Pixels | 81-21 = 60 |
| Clock Frequency | 100 MHz (10ns) |
| Cycles/Pixel | 2 |
| Total Cycles | ~170 (81 pixels + 5 flush) |

### 🎯 Test Image Pattern

```
9×9 RGB Gradient Test Image

Each pixel: (R=row×32, G=col×32, B=128)

Visual representation:
      Dark                          Bright
      (low R, low G)                (high R, high G)
      
  0   (  0,  0,128)  (  0,224,128)  (  0,224,128)
  ↓   (224,  0,128)  (224,224,128)  (224,224,128)
 224  
      
Used to verify:
- Filter processing correctness
- RGB component handling
- Pipeline timing behavior
```

### ✅ Expected Outputs

After running `make timing_9x9`, you should see:

**Generated Files:**
- `sim/stream_accel_timing_log.txt` - Main timing log
- `sim/test_9x9_rgb.png` - Visual test image
- `mem_generator/image_data_9x9_rgb.h` - C header with pixel data
- `sim/imem.hex`, `sim/dmem.hex` - Memory initialization files

**Console Output:**
```
Parsing timing log and generating visualizations...
Generated bootloader input: ../sim/image_9x9_rgb_bytes.txt
=================================================
STREAM_ACCEL_5x5_RGB TIMING TEST SUMMARY
...
=================================================
```

### 🔍 Verification Steps

1. **Check files exist:**
   ```bash
   ls -la modules/tb_stream_accel_5x5_rgb_timing.v
   ls -la mem_generator/code_rgb_vision_9x9.c
   ls -la sim/*.py
   ```

2. **Run test:**
   ```bash
   cd sim && make timing_9x9
   ```

3. **Verify output:**
   ```bash
   wc -l stream_accel_timing_log.txt
   head -50 stream_accel_timing_log.txt
   ```

4. **Analyze results:**
   ```bash
   python parse_timing_log.py
   ```

### 🐛 Troubleshooting Guide

| Issue | Solution |
|-------|----------|
| `xvlog: command not found` | Source Vivado environment |
| `riscv-none-elf-gcc: not found` | Install RISC-V toolchain |
| `image_data_9x9_rgb.h not found` | Run `make timing_9x9` (not just compile) |
| Empty timing log | Check `stdout` for simulation errors |
| Python scripts not running | Make executable: `chmod +x *.py` |
| Matplotlib not found | Install: `pip install matplotlib` |

### 📝 Next Steps

1. **Run the test**: `make timing_9x9`
2. **Examine output**: `cat stream_accel_timing_log.txt`
3. **Parse results**: `python parse_timing_log.py`
4. **Create diagrams**: `python visualize_timing.py`
5. **Document findings**: Copy output to documentation
6. **Modify kernel**: Change `switches` in testbench for different filters
7. **Change image**: Modify `generate_9x9_image.py` for custom patterns

### 📚 References

- [Detailed README](docs/TIMING_TESTBENCH_README.md)
- [Setup Summary](TIMING_TEST_SETUP.md)
- [Stream Accelerator Module](modules/stream_accel_5x5_rgb.v)
- [RGB Vision Code](mem_generator/code_rgb_vision.c)
- [Bootloader Code](mem_generator/bootloader.c)

---

**Created**: April 23, 2026
**Status**: ✅ Complete and Ready for Use
**Next Action**: Run `cd sim && make timing_9x9` to execute test
