import argparse
import re
from pathlib import Path


def extract_words(header_text):
    return [int(m.group(1), 16) for m in re.finditer(r"0x([0-9A-Fa-f]{8})", header_text)]


def write_bootloader_bytes(words, out_path):
    with out_path.open("w", encoding="utf-8") as handle:
        for word in words:
            b = word & 0xFF
            g = (word >> 8) & 0xFF
            r = (word >> 16) & 0xFF
            a = (word >> 24) & 0xFF

            # Bootloader writes one byte at a time to little-endian memory.
            # Byte order below reconstructs 32-bit words as 0x00RRGGBB in DMEM.
            handle.write(f"{b}\n")
            handle.write(f"{g}\n")
            handle.write(f"{r}\n")
            handle.write(f"{a}\n")


def main():
    parser = argparse.ArgumentParser(description="Generate bootloader byte stream from image_data_rgb.h")
    parser.add_argument("--input", default="../mem_generator/image_data_rgb.h", help="Path to RGB header file")
    parser.add_argument("--output", default="original_image_rgb_bytes.txt", help="Output text file with one byte per line")
    args = parser.parse_args()

    in_path = Path(args.input)
    out_path = Path(args.output)

    if not in_path.exists():
        raise FileNotFoundError(f"Input file not found: {in_path}")

    words = extract_words(in_path.read_text(encoding="utf-8", errors="ignore"))
    if not words:
        raise RuntimeError("No 32-bit RGB words found in input header")

    write_bootloader_bytes(words, out_path)

    print(f"Generated {out_path} from {len(words)} RGB words ({len(words) * 4} bootloader bytes).")


if __name__ == "__main__":
    main()
