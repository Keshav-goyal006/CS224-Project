from PIL import Image

def convert_rgb_image(input_filename, output_filename):
    # Resize to 64x48 and keep as RGB
    img = Image.open(input_filename).resize((64, 48)).convert('RGB')
    pixels = list(img.getdata()) # Returns a list of tuples: [(R,G,B), (R,G,B)...]

    with open(output_filename, 'w') as f:
        f.write("#include <stdint.h>\n\n")
        f.write("// 64x48 RGB Image (9216 Bytes)\n")
        # Multiply length by 3 because each pixel has 3 numbers
        f.write(f"const uint8_t image_pixels[{len(pixels) * 3}] = {{\n")
        
        for r, g, b in pixels:
            f.write(f"    {r}, {g}, {b},\n")
            
        f.write("};\n")
    print("Success! Converted to RGB C-Header.")

def convert_rgb_image_to_txt(input_filename, output_filename):
    img = Image.open(input_filename).resize((64, 48)).convert('RGB')
    pixels = list(img.getdata())

    with open(output_filename, 'w') as f:
        for r, g, b in pixels:
            # Write out each color channel on a new line
            f.write(f"{r}\n{g}\n{b}\n")
    print("Success! Converted to RGB TXT.")

convert_rgb_image('image.png', 'image_data_rgba.h')
convert_rgb_image_to_txt('image.png', '../sim/original_image_rgb.txt')
