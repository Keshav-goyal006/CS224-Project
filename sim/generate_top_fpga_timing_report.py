#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re


def parse_sim_log(log_path: Path) -> tuple[list[str], int | None]:
    events: list[str] = []
    finish_time_ns: int | None = None

    finish_re = re.compile(r"\$finish called at time\s*:\s*(\d+)\s*ns")

    for raw in log_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if line.startswith("INFO:") or line.startswith("PASS:"):
            events.append(line)
        m = finish_re.search(line)
        if m:
            finish_time_ns = int(m.group(1))

    return events, finish_time_ns


def parse_pixels(pixel_path: Path) -> tuple[int, int, int | None, str | None]:
    values = [line.strip() for line in pixel_path.read_text(encoding="utf-8", errors="ignore").splitlines() if line.strip()]
    total = len(values)

    first_idx = None
    first_val = None
    nonzero = 0
    for idx, v in enumerate(values):
        if v != "00000000":
            nonzero += 1
            if first_idx is None:
                first_idx = idx
                first_val = v

    return total, nonzero, first_idx, first_val


def build_txt_report(events: list[str], finish_time_ns: int | None, total: int, nonzero: int, first_idx: int | None, first_val: str | None) -> str:
    sim_cycles = (finish_time_ns // 10) if finish_time_ns is not None else None
    nonzero_pct = (100.0 * nonzero / total) if total else 0.0

    out: list[str] = []
    out.append("TOP_FPGA + STREAM_ACCEL_5x5_RGB TIMING REPORT")
    out.append("Generated from tb_pipeline_vga_bootloader simulation outputs")
    out.append("")
    out.append("======================")
    out.append("Simulation Summary")
    out.append("======================")
    out.append(f"Finish time (ns): {finish_time_ns if finish_time_ns is not None else 'N/A'}")
    out.append(f"Approx total cycles @100MHz (10ns): {sim_cycles if sim_cycles is not None else 'N/A'}")
    out.append("")
    out.append("======================")
    out.append("Pixel Evidence")
    out.append("======================")
    out.append(f"Total captured pixels: {total}")
    out.append(f"Non-zero pixels: {nonzero}")
    out.append(f"Non-zero percentage: {nonzero_pct:.2f}%")
    out.append(f"First non-zero pixel index: {first_idx if first_idx is not None else 'N/A'}")
    out.append(f"First non-zero pixel value: 0x{first_val if first_val is not None else 'N/A'}")
    out.append("")

    out.append("============================================")
    out.append("Ordered Runtime Events (from simulation log)")
    out.append("============================================")
    for idx, ev in enumerate(events, start=1):
        out.append(f"{idx:02d}. {ev}")

    out.append("")
    out.append("Conclusion:")
    if nonzero > 0:
        out.append("- stream_accel_5x5_rgb is driving visible (non-zero) pixels through VRAM/VGA path.")
    else:
        out.append("- No non-zero pixels observed; check accelerator data path.")

    return "\n".join(out) + "\n"


def build_mermaid(events: list[str]) -> str:
    # Sequence diagram is event-order accurate (not cycle-accurate), derived from testbench logs.
    lines: list[str] = []
    lines.append("sequenceDiagram")
    lines.append("    autonumber")
    lines.append("    participant TB as tb_pipeline_vga_bootloader")
    lines.append("    participant CPU as pipe")
    lines.append("    participant BUS as soc_interconnect")
    lines.append("    participant ACC as stream_accel_5x5_rgb")
    lines.append("    participant VRAM as dual_port_vram")
    lines.append("    participant VGA as vga_controller")
    lines.append("")

    lines.append("    TB->>CPU: Release reset and start bootloader emulation")
    lines.append("    TB->>BUS: Feed UART bytes (49152 bytes)")
    lines.append("    BUS->>CPU: Boot data writes into DMEM")
    lines.append("    TB->>CPU: SW[15] low (start processing)")
    lines.append("    CPU->>BUS: Memory-mapped ACCEL writes/reads")
    lines.append("    BUS->>ACC: Pixel stream + kernel mode")
    lines.append("    ACC-->>BUS: Filtered RGB results")
    lines.append("    BUS->>VRAM: Write 12288 output pixels")
    lines.append("    VGA->>VRAM: Scanout reads")
    lines.append("    VRAM-->>VGA: RGB pixel data")
    lines.append("    TB->>VGA: Capture full frame (12288 pixels)")
    lines.append("    TB-->>TB: Write vga_frame_pixels.txt")
    lines.append("")

    lines.append("    Note over TB,VGA: Event order from simulation log")
    for ev in events[:16]:
        escaped = ev.replace(":", " -", 1)
        lines.append(f"    Note over TB: {escaped}")

    return "\n".join(lines) + "\n"


def main() -> None:
    sim_dir = Path(__file__).resolve().parent
    root_dir = sim_dir.parent
    docs_dir = root_dir / "docs"

    log_path = sim_dir / "stdout_vga_timing"
    pixel_path = sim_dir / "vga_frame_pixels.txt"

    if not log_path.exists():
        raise FileNotFoundError(f"Missing simulation log: {log_path}")
    if not pixel_path.exists():
        raise FileNotFoundError(f"Missing pixel file: {pixel_path}")

    events, finish_time_ns = parse_sim_log(log_path)
    total, nonzero, first_idx, first_val = parse_pixels(pixel_path)

    docs_dir.mkdir(parents=True, exist_ok=True)

    txt_report = build_txt_report(events, finish_time_ns, total, nonzero, first_idx, first_val)
    mmd_diagram = build_mermaid(events)

    txt_path = docs_dir / "top_fpga_stream_rgb_timing_report.txt"
    mmd_path = docs_dir / "top_fpga_stream_rgb_timing_diagram.mmd"

    txt_path.write_text(txt_report, encoding="utf-8")
    mmd_path.write_text(mmd_diagram, encoding="utf-8")

    print(f"Wrote {txt_path}")
    print(f"Wrote {mmd_path}")


if __name__ == "__main__":
    main()
