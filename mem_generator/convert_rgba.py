from PIL import Image

def convert_image(input_filename, output_filename):
    # Open image, convert to RGB, and scale to 128x96
    img = Image.open(input_filename).convert("RGB")
    img = img.resize((128, 96))
    pixels = img.load()

    with open(output_filename, "w") as f:
        f.write("#ifndef IMAGE_DATA_H\n")
        f.write("#define IMAGE_DATA_H\n\n")
        f.write("#include <stdint.h>\n\n")
        
        # 128 * 96 = 12,288 pixels
        f.write("const uint32_t image_array[12288] = {\n")

        count = 0
        for y in range(96):
            for x in range(128):
                r, g, b = pixels[x, y]
                
                # Pack into 32-bit word: 0x00RRGGBB
                hex_val = (r << 16) | (g << 8) | b
                
                f.write(f"0x{hex_val:08X}, ")
                count += 1
                
                # formatting for readability
                if count % 8 == 0:
                    f.write("\n")

        f.write("};\n\n")
        f.write("#endif\n")
        print(f"Successfully converted {input_filename} to {output_filename}")

# Run the conversion
convert_image("image.png", "image_data_rgb.h")