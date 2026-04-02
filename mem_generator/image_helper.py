# image_helper.py
from PIL import Image

# 1. Open a tiny image and convert to grayscale
img = Image.open("test_image.png").convert('L')
img = img.resize((10, 10)) # Keep it tiny for simulation!
pixels = list(img.getdata())

# 2. Format as a C array
print("int32_t image_data[100] = {")
for i in range(0, len(pixels), 10):
    row = pixels[i:i+10]
    print("    " + ", ".join(str(p) for p in row) + ",")
print("};")