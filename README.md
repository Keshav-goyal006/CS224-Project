# CS224 FPGA Vision SoC

## Overview
This repository contains a hardware-software co-design project targeting the Digilent Nexys A7 FPGA board. The design integrates a RISC-V pipeline, memory-mapped peripherals, UART bootloading, VGA output, and streaming convolution accelerators for image-processing workloads.

The project supports both:
- Functional simulation (Vivado xsim flow)
- FPGA implementation and bring-up (Vivado synth/impl/bitstream flow)

## Architecture Summary
- CPU: RV32IM-style pipeline with instruction and data memory
- Interconnect: Memory-mapped SoC decode for DMEM, accelerator, LED, UART, VRAM, and control/status
- Boot flow: UART-based image loader before application execution
- Acceleration: Streaming convolution blocks (5x5 RGB active flow, plus 5x5/9x9 variants in repository)
- Display/IO: VGA pipeline, UART RX/TX, switches, LEDs

## Repository Layout
- `modules/`: RTL modules (pipeline stages, memory, interconnect, UART, accelerator, VGA, testbenches)
- `top/`: FPGA top-level and board constraints
- `mem_generator/`: RISC-V firmware sources and memory image generation
- `mem_generator/memory-map/`: BRAM memory-map artifacts for updatemem workflows
- `sim/`: Simulation make flow, file list, UART utilities, and output rendering scripts

## Development Progress (Commit-Based)
This section is generated directly from `git log` so it reflects actual repository activity.

<!-- PROGRESS_TABLE_START -->
| Date | Commit | Message |
|---|---|---|
| 2026-04-18 | `7dcc3ec` | Readme |
| 2026-04-18 | `3d52637` | FPGA working (grayscale) |
| 2026-04-18 | `107d6e8` | new files |
| 2026-04-18 | `049e7ef` | Mini Demo done |
| 2026-04-15 | `b27e542` | Erosion filter added |
| 2026-04-15 | `4f51b4a` | rgb implemented only in testbench |
| 2026-04-15 | `bdce6b5` | Memory increased and so increase the size of kernel |
| 2026-04-12 | `07832f6` | memory mapping |
| 2026-04-12 | `3f7fa38` | working top |
| 2026-04-12 | `b1e6684` | 5x5 convolution implemented |
| 2026-04-12 | `437199d` | Line buffers implemented and kernels integrated to switches |
| 2026-04-12 | `ae49290` | Eliminated hazard and is working on UART |
| 2026-04-11 | `7745627` | New changes |
| 2026-04-03 | `8ffa00b` | Merge pull request #8 from Keshav-goyal006/Dhairya-goyal |
| 2026-04-03 | `2610493` | Merge pull request #7 from Keshav-goyal006/Madhav |
| 2026-04-03 | `b56396b` | Merge branch 'main' into Madhav |
| 2026-04-03 | `f38efd3` | All done. |
| 2026-04-03 | `9e5b9d7` | Merge pull request #6 from Keshav-goyal006/Ayush-Garg |
| 2026-04-03 | `365b810` | added xdc |
| 2026-04-03 | `f00b64f` | correction |
| 2026-04-03 | `adc3b1e` | Merge pull request #5 from Keshav-goyal006/Ayush-Garg |
| 2026-04-03 | `658fb02` | Added vga_controller |
| 2026-04-03 | `07ec8fb` | Merge pull request #4 from Keshav-goyal006/Keshav |
| 2026-04-03 | `a495851` | conv |
| 2026-04-03 | `228fb3b` | Merge pull request #3 from Keshav-goyal006/Keshav |
| 2026-04-03 | `44f0777` | Conv-accelerator |
| 2026-04-01 | `a475fe1` | Image processor |
| 2026-04-01 | `61a5670` | Merge pull request #2 from Keshav-goyal006/Keshav |
| 2026-04-01 | `6fffded` | Folders made |
| 2026-03-30 | `b532690` | MAC implemented |
| 2026-03-30 | `2ec9929` | This is the first Commit. The RV32M Instruction Set implemented. Also MAC implemented. |
| 2026-03-29 | `09a8662` | Add files via upload |
| 2026-03-29 | `ae839ab` | Initial commit |
<!-- PROGRESS_TABLE_END -->

### Activity Gaps (Commit Dates)
<!-- PROGRESS_GAPS_START -->
- 2026-04-16 to 2026-04-17: no commits (2 days)
- 2026-04-13 to 2026-04-14: no commits (2 days)
- 2026-04-04 to 2026-04-10: no commits (7 days)
- 2026-04-02: no commits (1 day)
- 2026-03-31: no commits (1 day)
<!-- PROGRESS_GAPS_END -->

To refresh this section in the future:

```bash
make progress
```

Reference command used by the generator:

```bash
git log --date=short --pretty=format:"%h|%ad|%s" -n 50
```

## Prerequisites
- AMD Vivado (tested with 2025.2), including `xvlog`, `xelab`, `xsim`
- GNU Make
- RISC-V GNU toolchain (`riscv-none-elf-gcc`, `objcopy`, `objdump`)
- Python 3.10+ and packages:
	- `pyserial`
	- `numpy`
	- `matplotlib`
	- `pillow`

Recommended install command:

```bash
py -m pip install pyserial numpy matplotlib pillow
```

## Build and Run

### 1) Quick Simulation Flow (Recommended First)
From repository root:

```bash
make bootloader
```

This runs the integrated simulation flow in `sim/` and automatically builds firmware images from `mem_generator/`.

Optional image rendering from simulation outputs:

```bash
cd sim
py rgb_img.py
```

### 2) Firmware Image Generation Only
If you want only firmware/memory artifacts:

```bash
cd mem_generator
make bootloader
```

Generated files are placed under `mem_generator/imem_dmem/`:
- `imem.bin`, `imem.hex`, `imem.mem`
- `dmem.bin`, `dmem.hex`, `dmem.mem`
- `code.dis`

### 3) FPGA Bitstream Flow
1. Open/create Vivado project.
2. Add RTL sources from `modules/` and top-level `top/top_fpga.v`.
3. Add board constraints matching top ports (typically `modules/led.xdc` in this repository layout).
4. Set top module to `top_fpga`.
5. Run synthesis, implementation, and bitstream generation.
6. Program FPGA.

### 4) Hardware Runtime Sequence (Bootloader + UART)
1. Set `SW[15]` high (bootloader load mode).
2. (Optional) Regenerate RGB bootloader input bytes from the RGB header:

```bash
cd sim
py gen_rgb_bootloader_input.py --input ../mem_generator/image_data_rgb.h --output original_image_rgb_bytes.txt
```

3. Send image payload over UART:

```bash
cd sim
py uart_sender_rgb.py --port COM8 --baud 115200
```

4. Set `SW[15]` low to begin processing/output phase.
5. Capture RGB UART output and reconstruct an image:

```bash
cd sim
py uart_receiver_rgb.py --port COM8 --baud 115200 --width 128 --height 96 --output uart_rgb_output.png
```

## Notes and Operational Expectations
- Current RGB flow uses `128x96` pixels (`12288` total pixels).
- Bootloader RX input expects `49152` bytes (`12288` pixels x 4 bytes per pixel in `0x00RRGGBB` memory layout).
- UART TX output streams `R,G,B` bytes per pixel (`36864` bytes total per frame).
- VGA path displays RGB output and scales the `128x96` framebuffer to a `512x384` draw area.
- Memory initialization paths in `modules/memory.v` currently use absolute paths. If you move the repository, update those paths accordingly.

## Troubleshooting Checklist
- No LED/output activity:
	- Confirm reset polarity and constraint file matches top-level ports.
	- Confirm `SW[15]` sequence is followed (high for load, low for run).
	- Confirm UART COM port and baud are correct (`115200`).
- Missing or incomplete RGB output image:
	- Verify full payload length is transmitted (`49152` input bytes).
	- Verify receiver gets exactly `36864` output bytes before timeout.
	- Verify sender/receiver scripts are the RGB versions (`uart_sender_rgb.py`, `uart_receiver_rgb.py`).
	- Verify synthesis log reports successful `$readmemh` for IMEM/DMEM files.