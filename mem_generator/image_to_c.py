#!/usr/bin/env python3
from PIL import Image
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print(f"Usage: {sys.argv[0]} <input_image> <output_header> [output_coe]")
        return 1

    input_path = sys.argv[1]
    output_header = sys.argv[2]
    output_coe = sys.argv[3] if len(sys.argv) == 4 else str(Path(output_header).with_name("image.coe"))

    image = Image.open(input_path).convert("L").resize((10, 10), Image.Resampling.NEAREST)
    pixels = list(image.getdata())

    with open(output_header, "w", encoding="utf-8") as output_file:
        output_file.write("#ifndef IMAGE_DATA_H\n")
        output_file.write("#define IMAGE_DATA_H\n\n")
        output_file.write("#include <stdint.h>\n\n")
        output_file.write("const uint8_t image_data[100] = {\n")

        for row_start in range(0, 100, 10):
            row = pixels[row_start:row_start + 10]
            values = ", ".join(str(pixel) for pixel in row)
            suffix = "," if row_start < 90 else ""
            output_file.write(f"    {values}{suffix}\n")

        output_file.write("};\n\n")
        output_file.write("#endif\n")

    with open(output_coe, "w", encoding="utf-8") as coe_file:
        coe_file.write("memory_initialization_radix=16;\n")
        coe_file.write("memory_initialization_vector=\n")
        for i, pixel in enumerate(pixels):
            value = f"{pixel:02X}"
            suffix = ";\n" if i == len(pixels) - 1 else ",\n"
            coe_file.write(value + suffix)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())