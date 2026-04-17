import struct

MEMINIT = 1
RAMSIZE = 4096
WORD_BYTES = 4
MAX_WORDS = RAMSIZE // WORD_BYTES


def bin2hex(in_file, out_file):
    words_written = 0

    with open(in_file, "rb") as input_file, open(out_file, "w") as output_file:
        while True:
            data = input_file.read(WORD_BYTES)
            if not data:
                break

            if len(data) < WORD_BYTES:
                data += b"\x00" * (WORD_BYTES - len(data))

            value = struct.unpack("<I", data)[0]
            output_file.write(f"{value:08x}\n")
            words_written += 1

        while words_written < MAX_WORDS:
            output_file.write("00000000\n" if MEMINIT else "xxxxxxxx\n")
            words_written += 1

    print(f"Done! Created {out_file}. Total words: {words_written}/{MAX_WORDS}")


def hex2mem(in_file, out_file):
    with open(in_file, "r") as input_file, open(out_file, "w") as output_file:
        output_file.write("@00000000\n")

        for line in input_file:
            clean_line = line.split("//")[0].split("#")[0].strip()
            if clean_line and not clean_line.startswith("@"):
                output_file.write(clean_line + "\n")

    print(f"Done! Created {out_file} for updatemem.")


if __name__ == "__main__":
    bin2hex("imem.bin", "imem.hex")
    bin2hex("dmem.bin", "dmem.hex")
    hex2mem("imem.hex", "imem.mem")
    hex2mem("dmem.hex", "dmem.mem")
