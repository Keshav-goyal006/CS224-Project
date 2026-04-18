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
- Acceleration: Streaming convolution blocks (5x5 and 9x9 variants in repository)
- Display/IO: VGA pipeline, UART RX/TX, switches, LEDs

## Repository Layout
- `modules/`: RTL modules (pipeline stages, memory, interconnect, UART, accelerator, VGA, testbenches)
- `top/`: FPGA top-level and board constraints
- `mem_generator/`: RISC-V firmware sources and memory image generation
- `mem_generator/memory-map/`: BRAM memory-map artifacts for updatemem workflows
- `sim/`: Simulation make flow, file list, UART utilities, and output rendering scripts

## Development Progress (Commit-Based)
Recent milestones inferred from project history:

| Date | Commit | Milestone |
|---|---|---|
| 2026-04-18 | `3d52637` | FPGA grayscale flow reported working |
| 2026-04-18 | `049e7ef` | Mini demo completed |
| 2026-04-15 | `b27e542` | Erosion filter integrated |
| 2026-04-15 | `bdce6b5` | Memory size and kernel size expanded |
| 2026-04-12 | `07832f6` | Memory map integration |
| 2026-04-12 | `3f7fa38` | Top-level integration stabilized |
| 2026-04-12 | `b1e6684` | 5x5 convolution implementation |
| 2026-04-12 | `437199d` | Line buffers and switch-controlled kernels integrated |
| 2026-04-12 | `ae49290` | Hazard work and UART bring-up progress |
| 2026-04-03 | `658fb02` | VGA controller integration |
| 2026-04-03 | `44f0777` | Initial convolution accelerator commit |

To refresh this section in the future:

```bash
git log --date=short --pretty=format:"%h|%ad|%s" -n 25
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
py render_output.py
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
2. Send image payload over UART:

```bash
cd sim
py uart_sender.py --port COM8 --input original_image.txt --baud 115200
```

3. Set `SW[15]` low to begin processing/output phase.
4. Optionally capture UART output:

```bash
cd sim
py uart_listener.py
```

## Notes and Operational Expectations
- The current bootloader flow expects `49152` image bytes (256x192 grayscale).
- Memory initialization paths in `modules/memory.v` currently use absolute paths. If you move the repository, update those paths accordingly.
- Warnings related to missing `vram_init.hex` affect VRAM prefill behavior, not IMEM/DMEM compilation directly.

## Troubleshooting Checklist
- No LED/output activity:
	- Confirm reset polarity and constraint file matches top-level ports.
	- Confirm `SW[15]` sequence is followed (high for load, low for run).
	- Confirm UART COM port and baud are correct (`115200`).
- Unexpected black output:
	- Verify full payload length is transmitted (`49152` bytes).
	- Verify synthesis log reports successful `$readmemh` for IMEM/DMEM files.