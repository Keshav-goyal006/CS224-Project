#!/usr/bin/env python3
"""
Visualize stream accelerator timing data with matplotlib.
Generates timing diagrams and analysis plots.
"""

import os
import re

def parse_timing_log(log_file):
    """Parse timing log and extract data."""
    cycles = []
    outputs = []
    r_values = []
    g_values = []
    b_values = []
    statuses = []
    
    if not os.path.exists(log_file):
        print(f"Error: {log_file} not found")
        return None
    
    with open(log_file, 'r') as f:
        for line in f:
            if '|' in line and 'CYCLE' not in line and '---' not in line:
                parts = [p.strip() for p in line.split('|')]
                if len(parts) >= 5:
                    try:
                        cycle = int(parts[0])
                        status = parts[4]
                        output = int(parts[3], 16)
                        
                        rgb_str = parts[2]
                        rgb_match = re.search(r'R=(\d+)\s+G=(\d+)\s+B=(\d+)', rgb_str)
                        
                        if rgb_match:
                            cycles.append(cycle)
                            outputs.append(output)
                            r_values.append(int(rgb_match.group(1)))
                            g_values.append(int(rgb_match.group(2)))
                            b_values.append(int(rgb_match.group(3)))
                            statuses.append(status)
                    except (ValueError, IndexError):
                        continue
    
    if not cycles:
        print("Warning: No data parsed")
        return None
    
    return {
        'cycles': cycles,
        'outputs': outputs,
        'r': r_values,
        'g': g_values,
        'b': b_values,
        'statuses': statuses
    }

def plot_timing_diagram(data):
    """Plot timing diagram with matplotlib."""
    try:
        import matplotlib.pyplot as plt
        import matplotlib.patches as mpatches
    except ImportError:
        print("matplotlib not installed. Install with: pip install matplotlib")
        return
    
    if not data:
        return
    
    cycles = data['cycles']
    outputs = data['outputs']
    r = data['r']
    g = data['g']
    b = data['b']
    statuses = data['statuses']
    
    # Convert outputs to RGB tuples normalized to 0-1
    rgb_normalized = []
    for out in outputs:
        r_val = ((out >> 16) & 0xFF) / 255.0
        g_val = ((out >> 8) & 0xFF) / 255.0
        b_val = (out & 0xFF) / 255.0
        rgb_normalized.append((r_val, g_val, b_val))
    
    # Create figure with subplots
    fig = plt.figure(figsize=(14, 10))
    
    # Plot 1: Output RGB value over time (as colored bars)
    ax1 = plt.subplot(3, 1, 1)
    for i, (cycle, rgb) in enumerate(zip(cycles, rgb_normalized)):
        ax1.bar(cycle, 256, color=rgb, width=8)
    ax1.set_ylabel('Output Color')
    ax1.set_xlabel('Cycle Number')
    ax1.set_title('Stream Accelerator Output - RGB Values Over Time')
    ax1.grid(True, alpha=0.3)
    
    # Plot 2: Individual R, G, B components
    ax2 = plt.subplot(3, 1, 2)
    r_out = [(out >> 16) & 0xFF for out in outputs]
    g_out = [(out >> 8) & 0xFF for out in outputs]
    b_out = [out & 0xFF for out in outputs]
    
    ax2.plot(cycles, r_out, 'r-', label='Red', linewidth=2, alpha=0.7)
    ax2.plot(cycles, g_out, 'g-', label='Green', linewidth=2, alpha=0.7)
    ax2.plot(cycles, b_out, 'b-', label='Blue', linewidth=2, alpha=0.7)
    ax2.set_ylabel('Component Value (0-255)')
    ax2.set_xlabel('Cycle Number')
    ax2.set_title('RGB Component Evolution')
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    ax2.set_ylim([0, 256])
    
    # Plot 3: Status phases (Warmup, Valid, Flush)
    ax3 = plt.subplot(3, 1, 3)
    colors = {'WARMUP': 'orange', 'VALID': 'green', 'FLUSH': 'red'}
    
    for i, (cycle, status) in enumerate(zip(cycles, statuses)):
        if status in colors:
            ax3.bar(cycle, 1, color=colors[status], width=8, alpha=0.7)
    
    ax3.set_ylabel('Status')
    ax3.set_xlabel('Cycle Number')
    ax3.set_title('Pipeline Status')
    ax3.set_ylim([0, 1.2])
    ax3.set_yticks([])
    
    # Add legend
    legend_patches = [
        mpatches.Patch(facecolor=colors['WARMUP'], label='Warmup (filling buffers)'),
        mpatches.Patch(facecolor=colors['VALID'], label='Valid (full 5x5 window)'),
        mpatches.Patch(facecolor=colors['FLUSH'], label='Flush (draining pipeline)')
    ]
    ax3.legend(handles=legend_patches, loc='upper right')
    ax3.grid(True, alpha=0.3, axis='x')
    
    plt.tight_layout()
    plt.savefig('timing_diagram.png', dpi=150, bbox_inches='tight')
    print("Saved timing diagram: timing_diagram.png")
    
    # Also create a detailed view focusing on valid region
    fig2, ax = plt.subplots(figsize=(16, 6))
    
    # Find valid region indices
    valid_indices = [i for i, s in enumerate(statuses) if s == 'VALID']
    if valid_indices:
        valid_cycles = [cycles[i] for i in valid_indices]
        valid_outputs = [outputs[i] for i in valid_indices]
        valid_rgb = [rgb_normalized[i] for i in valid_indices]
        
        for cycle, rgb in zip(valid_cycles, valid_rgb):
            ax.bar(cycle, 256, color=rgb, width=8)
        
        ax.set_ylabel('Output Color')
        ax.set_xlabel('Cycle Number')
        ax.set_title('Stream Accelerator - Valid Output Phase (Gaussian Blur Applied)')
        ax.grid(True, alpha=0.3)
        ax.set_xlim([min(valid_cycles) - 10, max(valid_cycles) + 10])
        
        plt.tight_layout()
        plt.savefig('timing_diagram_valid_region.png', dpi=150, bbox_inches='tight')
        print("Saved valid region diagram: timing_diagram_valid_region.png")
    
    try:
        plt.show()
    except:
        print("Could not display plots interactively")

def print_statistics(data):
    """Print statistical summary."""
    if not data:
        return
    
    cycles = data['cycles']
    outputs = data['outputs']
    statuses = data['statuses']
    
    warmup_count = sum(1 for s in statuses if 'WARMUP' in s)
    valid_count = sum(1 for s in statuses if 'VALID' in s)
    flush_count = sum(1 for s in statuses if 'FLUSH' in s)
    
    # Extract RGB values from outputs
    r_out = [(out >> 16) & 0xFF for out in outputs]
    g_out = [(out >> 8) & 0xFF for out in outputs]
    b_out = [out & 0xFF for out in outputs]
    
    print("\n" + "="*60)
    print("TIMING ANALYSIS STATISTICS")
    print("="*60)
    print(f"Total cycles: {len(cycles)}")
    print(f"Warmup cycles: {warmup_count}")
    print(f"Valid cycles: {valid_count}")
    print(f"Flush cycles: {flush_count}")
    print()
    
    if valid_count > 0:
        valid_idx = warmup_count
        valid_end_idx = warmup_count + valid_count
        
        valid_r = r_out[valid_idx:valid_end_idx]
        valid_g = g_out[valid_idx:valid_end_idx]
        valid_b = b_out[valid_idx:valid_end_idx]
        
        print("Valid Output Statistics:")
        print(f"  Red:   min={min(valid_r):3d}, max={max(valid_r):3d}, avg={sum(valid_r)/len(valid_r):.1f}")
        print(f"  Green: min={min(valid_g):3d}, max={max(valid_g):3d}, avg={sum(valid_g)/len(valid_g):.1f}")
        print(f"  Blue:  min={min(valid_b):3d}, max={max(valid_b):3d}, avg={sum(valid_b)/len(valid_b):.1f}")
        print()
        
        print(f"First valid output (cycle {cycles[valid_idx]}):")
        print(f"  Value: 0x{outputs[valid_idx]:08x} = RGB({r_out[valid_idx]}, {g_out[valid_idx]}, {b_out[valid_idx]})")
        print()
        
        print(f"Last valid output (cycle {cycles[valid_end_idx-1]}):")
        print(f"  Value: 0x{outputs[valid_end_idx-1]:08x} = RGB({r_out[valid_end_idx-1]}, {g_out[valid_end_idx-1]}, {b_out[valid_end_idx-1]})")
    
    print("="*60 + "\n")

if __name__ == "__main__":
    log_file = "stream_accel_timing_log.txt"
    
    print("Parsing timing log and generating visualizations...")
    data = parse_timing_log(log_file)
    
    if data:
        print_statistics(data)
        plot_timing_diagram(data)
        print("Visualization complete!")
    else:
        print("Failed to parse timing log")
