from PIL import Image
import re

def convert_output_to_image(input_filename, output_filename, width=128, height=96):
    # Create a blank RGB image
    img = Image.new("RGB", (width, height))
    pixels = img.load()

    # Read the raw memory dump
    with open(input_filename, "r") as f:
        raw_text = f.read()

    # Find all hex values in the file. 
    # This regex handles formats like "0x00FF0000", "00FF0000", or comma-separated lists.
    # It looks for anything that looks like a valid 32-bit hex string.
    hex_values = re.findall(r'(?:0x)?([0-9A-Fa-f]{8})', raw_text)

    if len(hex_values) < (width * height):
        print(f"Warning: Expected {width * height} pixels, but only found {len(hex_values)}.")

    pixel_count = 0
    for y in range(height):
        for x in range(width):
            if pixel_count < len(hex_values):
                # Parse the 32-bit hex string into an integer
                val = int(hex_values[pixel_count], 16)
                
                # Extract the RGB channels using bitwise masking
                r = (val >> 16) & 0xFF
                g = (val >> 8)  & 0xFF
                b = val & 0xFF
                
                # Write to the image
                pixels[x, y] = (r, g, b)
                pixel_count += 1
            else:
                # Fill missing data with bright pink to make errors obvious
                pixels[x, y] = (255, 0, 255) 

    # Save the reconstructed image
    img.save(output_filename)
    print(f"Successfully reconstructed {output_filename} from {pixel_count} pixels!")

if __name__ == "__main__":
    convert_output_to_image("simulated_pixels.txt", "filtered_output.png")

    try:
        convert_output_to_image("simulated_pixels_warm.txt", "filtered_output_warm.png")
    except FileNotFoundError:
        print("simulated_pixels_warm.txt not found; skipped warm-run image render.")