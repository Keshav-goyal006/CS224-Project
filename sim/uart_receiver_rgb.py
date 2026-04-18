import argparse
import time

import serial
from PIL import Image

DEFAULT_PORT = "COM8"
DEFAULT_BAUD = 115200
DEFAULT_WIDTH = 128
DEFAULT_HEIGHT = 96
DEFAULT_OUTPUT = "uart_rgb_output.png"
DEFAULT_RAW = "uart_rgb_output.bin"
DEFAULT_TIMEOUT = 8.0


def receive_exact_rgb(port, baud, expected_bytes, idle_timeout):
    data = bytearray()

    print(f"Listening on {port} @ {baud} baud...")
    print(f"Waiting for {expected_bytes} bytes ({expected_bytes // 3} RGB pixels)...")

    with serial.Serial(port, baud, timeout=0.5) as ser:
        last_data_time = time.time()

        while len(data) < expected_bytes:
            chunk = ser.read(min(4096, expected_bytes - len(data)))
            now = time.time()

            if chunk:
                data.extend(chunk)
                last_data_time = now
                print(f"\rReceived: {len(data)}/{expected_bytes} bytes", end="")
            elif (now - last_data_time) > idle_timeout:
                break

    print()
    return bytes(data)


def save_rgb_image(raw_bytes, width, height, png_path, raw_path):
    with open(raw_path, "wb") as handle:
        handle.write(raw_bytes)

    img = Image.frombytes("RGB", (width, height), raw_bytes)
    img.save(png_path)
    print(f"Saved RGB image: {png_path}")
    print(f"Saved raw UART dump: {raw_path}")


def main():
    parser = argparse.ArgumentParser(description="Receive RGB image over UART and reconstruct PNG.")
    parser.add_argument("--port", default=DEFAULT_PORT, help="Serial port (e.g. COM8)")
    parser.add_argument("--baud", type=int, default=DEFAULT_BAUD, help="UART baud rate")
    parser.add_argument("--width", type=int, default=DEFAULT_WIDTH, help="Image width")
    parser.add_argument("--height", type=int, default=DEFAULT_HEIGHT, help="Image height")
    parser.add_argument("--output", default=DEFAULT_OUTPUT, help="Output PNG path")
    parser.add_argument("--raw", default=DEFAULT_RAW, help="Output raw byte dump path")
    parser.add_argument("--idle-timeout", type=float, default=DEFAULT_TIMEOUT, help="Stop if no data arrives for this many seconds")
    args = parser.parse_args()

    expected = args.width * args.height * 3
    data = receive_exact_rgb(args.port, args.baud, expected, args.idle_timeout)

    if len(data) != expected:
        raise SystemExit(
            f"ERROR: expected {expected} bytes but received {len(data)} bytes. "
            "Check boot sequence, baud, and whether FPGA finished transmitting."
        )

    save_rgb_image(data, args.width, args.height, args.output, args.raw)


if __name__ == "__main__":
    main()
