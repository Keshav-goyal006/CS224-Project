#!/usr/bin/env python3
"""
Generate a 9x9 RGB test image for stream accelerator timing analysis.
Creates an image with gradient patterns to visualize filter operations.
"""

from PIL import Image, ImageDraw

def generate_9x9_test_image(output_file):
    """Generate a 9x9 RGB test image with gradient patterns."""
    
    # Create a 9x9 RGB image
    img = Image.new('RGB', (9, 9), color='white')
    pixels = img.load()
    
    # Create a gradient pattern to visualize the filter
    # Row gradient: Red intensity increases down (0 to 255)
    # Column gradient: Green intensity increases right (0 to 255)
    # Blue is constant at 128
    
    for row in range(9):
        for col in range(9):
            r = (row * 32) if row < 8 else 255      # Red increases top to bottom
            g = (col * 32) if col < 8 else 255      # Green increases left to right
            b = 128                                  # Blue constant
            pixels[col, row] = (r, g, b)
    
    # Save the image
    img.save(output_file)
    print(f"Generated 9x9 test image: {output_file}")
    
    # Also print pixel values for reference
    print("\nPixel values (format: R,G,B):")
    print("    ", end="")
    for col in range(9):
        print(f"  Col{col} ", end="")
    print()
    
    for row in range(9):
        print(f"R{row}: ", end="")
        for col in range(9):
            r, g, b = pixels[col, row]
            print(f"({r:3},{g:3},{b:3}) ", end="")
        print()

def convert_image_to_c_header(input_file, output_file):
    """Convert the 9x9 RGB image to a C header file."""
    img = Image.open(input_file).convert('RGB')
    pixels = list(img.getdata())
    
    with open(output_file, 'w') as f:
        f.write("#ifndef IMAGE_DATA_9x9_RGB_H\n")
        f.write("#define IMAGE_DATA_9x9_RGB_H\n\n")
        f.write("#include <stdint.h>\n\n")
        f.write("// 9x9 RGB Test Image (81 pixels x 3 bytes = 243 bytes)\n")
        f.write(f"uint32_t image_data_9x9_rgb[{len(pixels)}] = {{\n")
        
        for i, (r, g, b) in enumerate(pixels):
            rgb_value = (r << 16) | (g << 8) | b
            f.write(f"    0x{rgb_value:08x},")

            if (i + 1) % 9 == 0:
                f.write(f"  // Row {i // 9}\n")
            else:
                f.write("  ")
        
        f.write("};\n\n")
        f.write("#endif // IMAGE_DATA_9x9_RGB_H\n")
    
    print(f"Generated C header: {output_file}")

if __name__ == "__main__":
    img_file = "test_9x9_rgb.png"
    header_file = "image_data_9x9_rgb.h"
    
    generate_9x9_test_image(img_file)
    convert_image_to_c_header(img_file, header_file)
