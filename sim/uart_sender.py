import argparse
import os
import struct
import time

import serial

if not hasattr(serial, "Serial"):
    raise SystemExit(
        "PySerial is not the serial module being imported. Remove the 'serial' package and reinstall pyserial: "
        "py -m pip uninstall -y serial && py -m pip install --force-reinstall pyserial"
    )

DEFAULT_BAUD = 115200
DEFAULT_PORT = "COM8"
DEFAULT_INPUT = "original_image.txt"
DEFAULT_CHUNK_SIZE = 64
IMAGE_BYTES = 49152


def read_payload(path):
    if not os.path.exists(path):
        raise FileNotFoundError(f"Input file not found: {path}")

    ext = os.path.splitext(path)[1].lower()

    if ext in {".txt", ".mem", ".hex"}:
        values = []
        with open(path, "r") as handle:
            for line in handle:
                clean_line = line.split("//")[0].split("#")[0].strip()
                if not clean_line:
                    continue
                for token in clean_line.split():
                    if token.startswith("@"):
                        continue
                    values.append(int(token, 0))

        if not values:
            raise ValueError(f"No pixel data found in {path}")

        payload = bytes(value & 0xFF for value in values)
    else:
        with open(path, "rb") as handle:
            payload = handle.read()

    if len(payload) < IMAGE_BYTES:
        payload += b"\x00" * (IMAGE_BYTES - len(payload))
    elif len(payload) > IMAGE_BYTES:
        payload = payload[:IMAGE_BYTES]

    return payload


def send_image(port, input_path, baud_rate=DEFAULT_BAUD, chunk_size=DEFAULT_CHUNK_SIZE):
    payload = read_payload(input_path)

    print(f"Opening {port} at {baud_rate} baud...")
    print(f"Sending {len(payload)} bytes from {input_path}...")

    with serial.Serial(port, baud_rate, timeout=2) as ser:
        bytes_sent = 0
        start_time = time.time()

        for offset in range(0, len(payload), chunk_size):
            chunk = payload[offset:offset + chunk_size]
            ser.write(chunk)
            bytes_sent += len(chunk)
            progress = (bytes_sent / len(payload)) * 100
            print(f"\rProgress: [{bytes_sent}/{len(payload)} bytes] {progress:.1f}%", end="")
            time.sleep(0.005)

        ser.flush()
        elapsed = time.time() - start_time
        print(f"\n\nUpload complete in {elapsed:.2f} seconds.")
        print("Flip the FPGA switch / warm-reset flow as needed to start processing.")


def main():
    parser = argparse.ArgumentParser(description="Send a 49152-byte grayscale image over UART.")
    parser.add_argument("--port", default=DEFAULT_PORT, help="Serial port, e.g. COM8")
    parser.add_argument("--input", default=DEFAULT_INPUT, help="Input image file (.bin, .txt, .hex, .mem)")
    parser.add_argument("--baud", type=int, default=DEFAULT_BAUD, help="UART baud rate")
    parser.add_argument("--chunk", type=int, default=DEFAULT_CHUNK_SIZE, help="Chunk size in bytes")
    args = parser.parse_args()

    send_image(args.port, args.input, baud_rate=args.baud, chunk_size=args.chunk)


if __name__ == "__main__":
    main()
