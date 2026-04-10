# vram_image_gen.py
from PIL import Image

# 1. Load your test image (put a test_image.jpg in the same folder)
# Convert it to 'L' (8-bit grayscale, where 0 is black, 255 is white)
try:
    img = Image.open("test_image.jpg").convert('L')
except FileNotFoundError:
    print("Please put a 'test_image.jpg' in this folder!")
    exit()

# 2. Resize to our hardware VRAM resolution (160 width, 120 height)
img = img.resize((160, 120))
pixels = list(img.getdata())

# 3. Write out to a standard Verilog hex file
# We will have 19,200 lines, each containing a 2-digit hex number (00 to FF)
with open("vram_init.hex", "w") as f:
    for p in pixels:
        # Convert integer to a 2-digit uppercase hex string (e.g., 255 -> FF)
        hex_val = "{:02X}".format(p)
        f.write(hex_val + "\n")

print("Successfully generated vram_init.hex with 19,200 pixels!")