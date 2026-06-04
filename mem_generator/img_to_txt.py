import sys
import argparse
from PIL import Image

def png_to_txt_bytes(input_image_path, output_txt_path):
    try:
        # 1. Open the image
        img = Image.open(input_image_path)
        
        # 2. Convert to standard RGB 
        # (This strips away any Alpha/transparency channels so we reliably get 3 values)
        img = img.convert('RGB')
        
        # 3. Resize the image to 128 width and 96 height
        # Image.Resampling.LANCZOS gives a high-quality downsampling
        img = img.resize((128, 96), Image.Resampling.LANCZOS)
        
        # 4. Open the text file for writing
        with open(output_txt_path, 'w') as f:
            
            # Iterate through every pixel row by row
            for y in range(img.height):
                for x in range(img.width):
                    # Get the Red, Green, and Blue values for the current pixel
                    r, g, b = img.getpixel((x, y))
                    
                    # Write the R G B 0 format, separated by spaces
                    f.write(f"{b} {g} {r} 0 ")
                
                # Optional: Adds a new line at the end of each row of 128 pixels
                # This makes the text file much easier to read without changing the data order
                f.write("\n")
                
        print(f"Success! Image converted and saved to {output_txt_path}")

    except Exception as e:
        print(f"An error occurred: {e}")

# ==========================================
# Example usage:
# python img_to_txt.py --input image.png
# python img_to_txt.py --input image.png
# Default input is image.png if not specified
# ==========================================
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert PNG image to text format")
    parser.add_argument("--input", type=str, default="image.png", 
                        help="Input image filename (default: image.png)")
    
    args = parser.parse_args()
    input_file = args.input
    output_file = "../sim/output.txt" 
    
    png_to_txt_bytes(input_file, output_file)