#!/usr/bin/env python3
"""
Generate bootloader input from 9x9 RGB image for stream accelerator simulation.
Converts RGB image pixels to bytes that the bootloader can receive.
"""

import os
import sys

def generate_9x9_bootloader_input(image_header_file, output_file):
    """
    Generate bootloader input from the image header file.
    The image_header_file should contain a C array of uint32_t RGB values.
    """
    
    pixels = []
    
    # Parse the header file to extract pixel values
    with open(image_header_file, 'r') as f:
        in_array = False
        for line in f:
            line = line.strip()
            
            if 'uint32_t' in line and '=' in line:
                in_array = True
                continue
            
            if in_array:
                if '};' in line:
                    break
                
                # Extract hex values
                parts = line.split(',')
                for part in parts:
                    part = part.strip()
                    if part.startswith('0x'):
                        pixels.append(int(part, 16))
    
    if not pixels:
        print(f"Warning: No pixels found in {image_header_file}")
        print("Generating default 9x9 gradient image...")
        
        # Generate default 9x9 gradient
        for row in range(9):
            for col in range(9):
                r = (row * 32) if row < 8 else 255
                g = (col * 32) if col < 8 else 255
                b = 128
                rgb = (r << 16) | (g << 8) | b
                pixels.append(rgb)
    
    # Write as bytes to bootloader input file
    with open(output_file, 'w') as f:
        for pixel in pixels:
            # Extract RGB components
            r = (pixel >> 16) & 0xFF
            g = (pixel >> 8) & 0xFF
            b = pixel & 0xFF
            a = (pixel >> 24) & 0xFF
            
            # Bootloader writes bytes into little-endian memory, so the word
            # must be reconstructed as B, G, R, A to yield 0x00RRGGBB in DMEM.
            f.write(f"{b}\n")
            f.write(f"{g}\n")
            f.write(f"{r}\n")
            f.write(f"{a}\n")
    
    print(f"Generated bootloader input: {output_file}")
    print(f"Total pixels: {len(pixels)}")
    print(f"Total bytes: {len(pixels) * 4}")

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Default paths resolved relative to sim/
    header_file = os.path.normpath(os.path.join(script_dir, "..", "mem_generator", "image_data_9x9_rgb.h"))
    output_file = os.path.normpath(os.path.join(script_dir, "image_9x9_rgb_bytes.txt"))
    
    # Check if header file exists
    if not os.path.exists(header_file):
        print(f"Header file not found: {header_file}")
        print("Run generate_9x9_image.py first")
        sys.exit(1)
    
    generate_9x9_bootloader_input(header_file, output_file)
