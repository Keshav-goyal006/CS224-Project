import struct
import time
MEMINIT = 1
RAMSIZE = 4096

def hexChange(string):
    string = string[2:]
    zeros = 8-len(string)
    new_str = "0"*zeros + string
    return new_str

def bin2hex(in_file, out_file):
	inputFile = open(in_file, 'rb')
	outputFile = open(out_file, 'w')
	j = 0
	chunk = 4
	while True:
		data = inputFile.read(chunk)
		if not data:
			break

		if len(data) < chunk:
			data += b'\x00' * (chunk - len(data))

		data = struct.unpack("I",data)
		outputFile.write(hexChange(str(hex(data[0]))) + "\n")
		# outputFile.write(hexChange(str(hex(data[0]))) + " // 32'h" + hexChange(str(hex(j)))+ "\n")
		j+=4
	
	while(j<RAMSIZE):
		if (MEMINIT):
			outputFile.write("00000000\n")
			# outputFile.write("00000000 // 32'h"+hexChange(str(hex(j)))+ "\n")
		else:
			outputFile.write("xxxxxxxx\n")
			# outputFile.write("xxxxxxxx // 32'h"+hexChange(str(hex(j))) + "\n")
		j+=4
	inputFile.close()
	outputFile.close()

def hextomem(in_file, out_file):
    with open(in_file, 'r') as f_in, open(out_file, 'w') as f_out:
        # 1. The mandatory Xilinx address header
        # f_out.write("@00000000\n")
        
        for line in f_in:
            # 2. Strip anything after // (the comments you showed me)
            clean_line = line.split("//")[0].strip()

            # 3. Only write if the line isn't empty
            if clean_line:
                # updatemem expects the 8-character hex string as TEXT
                f_out.write(clean_line + "\n")

    print(f"Done! Created {out_file} for updatemem.")

def hex2mem(in_file, out_file):
	inputFile = open(in_file, 'r')
	outputFile = open(out_file, 'w')
	outputFile.write("@00000000\n")
	for line in inputFile:
		clean_line = line.split()[0].strip()
		outputFile.write(clean_line + "\n")
	inputFile.close()
	outputFile.close()

def instr_hex_to_mem(in_file, out_file):
    # The pre-compiled RISC-V 4KB UART Bootloader (18 instructions)
    # NEW 3KB Bootloader starting at 0x1400
    bootloader_hex = [
        "000083b7", "000062b7", "0002a303", "00737333", "02030c63",
        "00001eb7", "400e8e93", "00002e37", "000052b7", "00c2a303",
        "fe030ce3", "0082a303", "006e8023", "001e8e93", "ffcec4e3",
        "000062b7", "0002a303", "00737333", "fe031ae3"
    ]
    
    # 4096 bytes / 4 bytes per instruction = 1024 maximum lines
    MAX_INSTRUCTIONS = 1024 

    with open(in_file, 'r') as inputFile, open(out_file, 'w') as outputFile:
        outputFile.write("@00000000\n")
        
        lines_written = 0

        # 1. Inject the Bootloader
        for instruction in bootloader_hex:
            outputFile.write(instruction + "\n")
            lines_written += 1

        # 2. Append main program, but cut off the excess padding!
        for line in inputFile:
            if lines_written >= MAX_INSTRUCTIONS:
                break # We hit 4KB, stop writing immediately.
                
            clean_line = line.split()[0].strip()
            if clean_line:
                outputFile.write(clean_line + "\n")
                lines_written += 1
                
    print(f"Done! Created {out_file} with embedded bootloader. Total words: {lines_written}/{MAX_INSTRUCTIONS}")

bin2hex("imem.bin", "imem.hex")
bin2hex("dmem.bin", "dmem.hex")
# time.sleep(10)
# hex2mem("imem.hex", "imem.mem")
instr_hex_to_mem("imem.hex", "imem.mem")
hex2mem("dmem.hex", "dmem.mem")
