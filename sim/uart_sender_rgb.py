import argparse
import os
import time
from pathlib import Path

import serial

IMAGE_BYTES = 49152
DEFAULT_PORT = "COM8"
DEFAULT_BAUD = 115200
DEFAULT_INPUT = "original_image_rgb_bytes.txt"
DEFAULT_HEADER = "../mem_generator/image_data_rgb.h"
DEFAULT_CHUNK = 64


def ensure_input_file(input_path, header_path):
    if os.path.exists(input_path):
        return

    from gen_rgb_bootloader_input import extract_words, write_bootloader_bytes

    if not os.path.exists(header_path):
        raise FileNotFoundError(
            f"Missing input payload ({input_path}) and header source ({header_path})."
        )

    with open(header_path, "r", encoding="utf-8", errors="ignore") as handle:
        words = extract_words(handle.read())

    if not words:
        raise RuntimeError(f"No RGB words found in {header_path}")

    write_bootloader_bytes(words, Path(input_path))
    print(f"Generated {input_path} from {header_path}.")


def read_payload(path):
    values = []
    with open(path, "r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            clean_line = line.split("//")[0].split("#")[0].strip()
            if not clean_line:
                continue
            for token in clean_line.split():
                if token.startswith("@"):
                    continue
                values.append(int(token, 0) & 0xFF)

    payload = bytes(values)
    if len(payload) < IMAGE_BYTES:
        payload += b"\x00" * (IMAGE_BYTES - len(payload))
    elif len(payload) > IMAGE_BYTES:
        payload = payload[:IMAGE_BYTES]

    return payload


def send_payload(port, baud, payload, chunk_size):
    print(f"Opening {port} at {baud} baud...")
    print(f"Sending {len(payload)} bytes to bootloader...")

    with serial.Serial(port, baud, timeout=2) as ser:
        sent = 0
        start = time.time()
        for idx in range(0, len(payload), chunk_size):
            chunk = payload[idx: idx + chunk_size]
            ser.write(chunk)
            sent += len(chunk)
            print(f"\rProgress: {sent}/{len(payload)} bytes", end="")
            time.sleep(0.003)

        ser.flush()
        elapsed = time.time() - start

    print(f"\nDone. Transfer completed in {elapsed:.2f}s.")
    print("Set SW[15] low (if high) to start processing.")


def main():
    parser = argparse.ArgumentParser(description="Send RGB bootloader payload over UART.")
    parser.add_argument("--port", default=DEFAULT_PORT, help="Serial port (e.g. COM8)")
    parser.add_argument("--baud", type=int, default=DEFAULT_BAUD, help="UART baud rate")
    parser.add_argument("--input", default=DEFAULT_INPUT, help="RGB bootloader byte file")
    parser.add_argument("--header", default=DEFAULT_HEADER, help="RGB header source used if input is missing")
    parser.add_argument("--chunk", type=int, default=DEFAULT_CHUNK, help="Chunk size in bytes")
    args = parser.parse_args()

    ensure_input_file(args.input, args.header)
    payload = read_payload(args.input)
    send_payload(args.port, args.baud, payload, args.chunk)


if __name__ == "__main__":
    main()
