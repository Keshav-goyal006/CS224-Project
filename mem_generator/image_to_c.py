import sys
from PIL import Image

def convert_image(image_path):
    try:
        # Open image and convert to grayscale ('L')
        img = Image.open(image_path).convert('L')
        # Resize to 8x8 using LANCZOS for best downsampling quality
        img = img.resize((8, 8), Image.Resampling.LANCZOS)
        
        pixels = list(img.getdata())
        
        print(f"// Generated from {image_path}")
        print("int image[8][8] = {")
        for y in range(8):
            row = pixels[y*8 : (y+1)*8]
            row_str = ", ".join(f"{val:3}" for val in row)
            print(f"    {{{row_str}}},")
        print("};")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python image_to_c.py <path_to_image>")
    else:
        convert_image(sys.argv[1])