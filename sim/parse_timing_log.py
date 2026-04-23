#!/usr/bin/env python3
"""
Parse stream accelerator timing log and generate visualizations.
"""

import re
import os

def parse_timing_log(log_file):
    """Parse the timing log file and extract cycle data."""
    
    if not os.path.exists(log_file):
        print(f"Error: {log_file} not found")
        return None
    
    cycles = []
    inputs = []
    outputs = []
    statuses = []
    
    with open(log_file, 'r') as f:
        for line in f:
            # Match data lines with pipe separators
            if '|' in line and 'CYCLE' not in line and '---' not in line:
                # Expected format:
                # cycle | hex_data | R=val G=val B=val | output | status
                
                parts = [p.strip() for p in line.split('|')]
                
                if len(parts) >= 5:
                    try:
                        cycle = int(parts[0])
                        status = parts[4]
                        
                        # Extract output (hex)
                        out_hex = parts[3]
                        output = int(out_hex, 16)
                        
                        # Try to extract RGB from input
                        rgb_str = parts[2]
                        rgb_match = re.search(r'R=(\d+)\s+G=(\d+)\s+B=(\d+)', rgb_str)
                        
                        if rgb_match:
                            r = int(rgb_match.group(1))
                            g = int(rgb_match.group(2))
                            b = int(rgb_match.group(3))
                            
                            cycles.append(cycle)
                            inputs.append((r, g, b))
                            outputs.append(output)
                            statuses.append(status)
                    except (ValueError, IndexError):
                        continue
    
    if not cycles:
        print("Warning: No data found in timing log")
        return None
    
    return {
        'cycles': cycles,
        'inputs': inputs,
        'outputs': outputs,
        'statuses': statuses
    }

def generate_summary(data):
    """Generate a summary of the timing test."""
    
    if not data:
        return
    
    cycles = data['cycles']
    statuses = data['statuses']
    outputs = data['outputs']
    
    warmup_count = sum(1 for s in statuses if 'WARMUP' in s)
    valid_count = sum(1 for s in statuses if 'VALID' in s)
    flush_count = sum(1 for s in statuses if 'FLUSH' in s)
    
    print("\n" + "="*60)
    print("STREAM ACCELERATOR TIMING TEST SUMMARY")
    print("="*60)
    print(f"Total cycles: {len(cycles)}")
    print(f"Warmup pixels: {warmup_count}")
    print(f"Valid outputs: {valid_count}")
    print(f"Flush cycles: {flush_count}")
    print(f"\nFirst valid output: Cycle {cycles[warmup_count]} = 0x{outputs[warmup_count]:08x}")
    print(f"Last valid output: Cycle {cycles[warmup_count + valid_count - 1]} = 0x{outputs[warmup_count + valid_count - 1]:08x}")
    print("="*60 + "\n")

def generate_markdown_table(data, output_file="timing_table.md"):
    """Generate a markdown table from timing data."""
    
    if not data:
        return
    
    cycles = data['cycles']
    inputs = data['inputs']
    outputs = data['outputs']
    statuses = data['statuses']
    
    with open(output_file, 'w') as f:
        f.write("# Stream Accelerator Timing Table\n\n")
        f.write("| Cycle | Input (R, G, B) | Output | Status |\n")
        f.write("|-------|-----------------|--------|--------|\n")
        
        for i, (cycle, inp, out, status) in enumerate(zip(cycles, inputs, outputs, statuses)):
            r, g, b = inp
            f.write(f"| {cycle:5d} | ({r:3d}, {g:3d}, {b:3d}) | 0x{out:08x} | {status:7s} |\n")
            
            # Add section breaks
            if i < len(statuses) - 1:
                if status != statuses[i+1]:
                    f.write("\n")
    
    print(f"Generated markdown table: {output_file}")

def generate_vcd_like_output(data, output_file="timing_waveform.txt"):
    """Generate a VCD-like text representation."""
    
    if not data:
        return
    
    cycles = data['cycles']
    outputs = data['outputs']
    statuses = data['statuses']
    
    with open(output_file, 'w') as f:
        f.write("Stream Accelerator Output Waveform\n")
        f.write("="*50 + "\n")
        f.write("Time (ns) | Output Value | Status\n")
        f.write("-"*50 + "\n")
        
        for cycle, out, status in zip(cycles, outputs, statuses):
            time_ns = cycle * 10  # 100 MHz = 10ns period
            r = (out >> 16) & 0xFF
            g = (out >> 8) & 0xFF
            b = out & 0xFF
            f.write(f"{time_ns:8d} | 0x{out:08x} RGB({r:3d},{g:3d},{b:3d}) | {status}\n")
    
    print(f"Generated waveform file: {output_file}")

if __name__ == "__main__":
    log_file = "stream_accel_timing_log.txt"
    
    print("Parsing timing log...")
    data = parse_timing_log(log_file)
    
    if data:
        generate_summary(data)
        generate_markdown_table(data)
        generate_vcd_like_output(data)
        print("\nTiming analysis complete!")
    else:
        print("Failed to parse timing log")
