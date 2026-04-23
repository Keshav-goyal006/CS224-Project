# ⚡ Quick Reference - Stream Accelerator Timing Test

## One-Shot Command

```bash
cd sim
make timing_9x9
```

This runs everything: image generation → compilation → simulation → logging

## What Gets Generated

| File | Purpose |
|------|---------|
| `stream_accel_timing_log.txt` | ⭐ Main output - cycle-by-cycle data |
| `test_9x9_rgb.png` | Visual test image |
| `image_data_9x9_rgb.h` | C header with pixel array |
| `timing_table.md` | Markdown timing table (after parsing) |
| `timing_diagram.png` | Plot visualization (after visualization) |

## View Results

```bash
# View timing log
less stream_accel_timing_log.txt

# Generate analysis
python parse_timing_log.py

# Create plots (requires matplotlib)
python visualize_timing.py

# View test image
open test_9x9_rgb.png  # macOS
display test_9x9_rgb.png  # Linux
```

## Understanding the Output

Each line in `stream_accel_timing_log.txt`:

```
Cycle | Input Pixel | R=val G=val B=val | Output RGB | Status
------|-------------|-------------------|------------|-------
45    | 00a08080    | R=160 G=128 B=128 | 00a2809f   | VALID
```

- **Cycle**: Clock cycle number (100MHz = 10ns per cycle)
- **Status**: WARMUP (filling buffers) / VALID (full 5x5 window) / FLUSH (draining)
- **Output**: Filtered pixel in 0x00RRGGBB format

## Test Phases

```
Cycles 0-20:   WARMUP (Line buffers filling, output unreliable)
Cycles 21-80:  VALID (Full 5x5 window, output is good)
Cycles 81-85:  FLUSH (Pushing zeros to drain pipeline)
```

## Test Image Pattern

```
9×9 Gradient:
- Red increases from top (0) to bottom (224)
- Green increases from left (0) to right (224)
- Blue constant at 128

Example corners:
  (0,0)     = (  0,   0, 128)  [dark]
  (0,8)     = (  0, 224, 128)  [cyan-ish]
  (8,0)     = (224,   0, 128)  [red-ish]
  (8,8)     = (224, 224, 128)  [yellow-ish]
```

## Key Parameters

| Parameter | Value |
|-----------|-------|
| Image | 9×9 = 81 pixels |
| Kernel | 5×5 Gaussian Blur |
| Window Valid After | Pixel 21 |
| Total Valid Outputs | 60 pixels |
| Processing Time | ~170 clock cycles |

## Change Kernel (in Testbench)

Edit `modules/tb_stream_accel_5x5_rgb_timing.v`:

```verilog
switches = 4'b0001;  // Current: Gaussian Blur

// Change to:
// switches = 4'b0010;  // Edge Detection
// switches = 4'b0100;  // Sharpen
// switches = 4'b0101;  // Unsharp Mask
// switches = 4'b0110;  // Vertical Sobel
```

Then re-run: `make timing_9x9`

## Change Image Size

Edit `mem_generator/code_rgb_vision_9x9.c`:

```c
enum {
    IMG_WIDTH = 9,      // Change to 16 for 16×16
    IMG_HEIGHT = 9,     // Change to 16 for 16×16
    ...
};
```

Also edit `mem_generator/generate_9x9_image.py`:

```python
img = Image.new('RGB', (9, 9), color='white')  # Change (9,9) to desired size
```

## Typical Workflow

```
1. Run test
   cd sim && make timing_9x9

2. View raw results
   less stream_accel_timing_log.txt

3. Parse and analyze
   python parse_timing_log.py

4. Create visualizations
   python visualize_timing.py

5. Include in documentation
   Copy timing_table.md to docs/
   Include timing_diagram.png in report
```

## Troubleshooting

| Error | Fix |
|-------|-----|
| `command not found: xvlog` | Source Vivado: `source /opt/Xilinx/Vivado/xxx/settings64.sh` |
| `riscv-none-elf-gcc: not found` | Install RISC-V tools or add to PATH |
| Empty timing log | Check `stdout` for errors, look at `xvlog.log` |
| Image file missing | Run full `make timing_9x9`, not individual targets |

## File Locations

```
d:\New\CS224\CS224-Project\
├── modules/
│   └── tb_stream_accel_5x5_rgb_timing.v
├── mem_generator/
│   ├── code_rgb_vision_9x9.c
│   ├── generate_9x9_image.py
│   └── Makefile (updated)
├── sim/
│   ├── gen_9x9_bootloader_input.py
│   ├── parse_timing_log.py
│   ├── visualize_timing.py
│   ├── Makefile (updated)
│   └── stream_accel_timing_log.txt (generated)
├── docs/
│   └── TIMING_TESTBENCH_README.md (detailed)
├── TIMING_TEST_SETUP.md
└── IMPLEMENTATION_CHECKLIST.md
```

## Documentation

- **Quick start**: This file
- **Detailed guide**: `docs/TIMING_TESTBENCH_README.md`
- **Setup overview**: `TIMING_TEST_SETUP.md`
- **Implementation verified**: `IMPLEMENTATION_CHECKLIST.md`

## Need More Details?

See `TIMING_TEST_SETUP.md` for comprehensive overview or `docs/TIMING_TESTBENCH_README.md` for full documentation.

---

**TL;DR**: Run `make timing_9x9` in sim/ folder, check `stream_accel_timing_log.txt`
