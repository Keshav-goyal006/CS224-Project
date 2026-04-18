from PIL import Image

def convert_image(input_filename, output_filename):
    # Resize to 64x48 to fit inside a 4KB memory!
    img = Image.open(input_filename).resize((64, 48)).convert('L')
    pixels = list(img.getdata())

    with open(output_filename, 'w') as f:
        f.write("#include <stdint.h>\n\n")
        f.write("// 64x48 Grayscale Image (3072 Bytes)\n")
        f.write(f"uint8_t image_pixels[{len(pixels)}] = {{\n")
        
        # Format it nicely into rows of 64
        for i in range(0, len(pixels), 64):
            row = pixels[i:i+64]
            row_str = ", ".join(str(p) for p in row)
            f.write(f"    {row_str},\n")
            
        f.write("};\n")
    print(f"Success! Converted {input_filename} to {output_filename}")

def convert_image_to_txt(input_filename, output_filename):
    img = Image.open(input_filename).resize((64, 48)).convert('L')
    pixels = list(img.getdata())

    with open(output_filename, 'w') as f:
        for p in pixels:
            f.write(f"{p}\n")
    print(f"Success! Converted {input_filename} to {output_filename}")

# Replace 'my_image.jpg' with your picture
convert_image('image.png', 'image_data.h')
convert_image_to_txt('image3.png', '../sim/original_image2.txt')