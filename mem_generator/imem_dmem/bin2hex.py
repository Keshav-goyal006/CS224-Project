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

def bin_to_hex_with_bootloader(bin_file, hex_out_file):
    """
    Convert a .bin file directly to .hex with bootloader prepended.
    Bootloader fills words 0-17, main program starts at word 18 (address 0x48).
    """
    bootloader_hex = [
        "000083b7", "000062b7", "0002a303", "00737333", "02030c63",
        "00001eb7", "00002e37", "000052b7", "00c2a303",
        "fe030ce3", "0082a303", "006e8023", "001e8e93", "ffcec4e3",
        "000062b7", "0002a303", "00737333", "fe031ae3"
    ]

    # bootloader_hex = [
    #     "000083b7", "000062b7", "0002a303", "00737333", "02030c63", 
    #     "00001eb7", "00002e37", "000052b7", "00c2a303", "fe030ce3", 
    #     "0082a303", "006e8023", "001e8e93", "ffcec4e3", "000062b7", 
    #     "0002a303", "00737333", "fe031ae3"                          
    # ]
    
    MAX_INSTRUCTIONS = 1024
    
    with open(bin_file, 'rb') as f:
        bin_data = f.read()
    
    with open(hex_out_file, 'w') as f:
        lines_written = 0
        
        # 1. Write bootloader (18 instructions)
        for instruction in bootloader_hex:
            f.write(instruction + "\n")
            lines_written += 1
        
        # 2. Convert binary to 32-bit words and write
        for i in range(0, len(bin_data), 4):
            if lines_written >= MAX_INSTRUCTIONS:
                break
            
            # Extract 4 bytes, handle padding if needed
            chunk = bin_data[i:i+4]
            if len(chunk) < 4:
                chunk += b'\x00' * (4 - len(chunk))
            
            # Convert to little-endian 32-bit unsigned int
            val = struct.unpack('<I', chunk)[0]
            hex_str = f"{val:08x}"
            f.write(hex_str + "\n")
            lines_written += 1
        
        # 3. Pad remaining space with zeros
        while lines_written < MAX_INSTRUCTIONS:
            f.write("00000000\n")
            lines_written += 1
    
    print(f"Done! Created {hex_out_file} with bootloader. Total words: {lines_written}/{MAX_INSTRUCTIONS}")

def instr_hex_to_mem(in_file, out_file):
    """
    Convert .hex file to .mem format for updatemem tool.
    Adds Xilinx address header @00000000.
    """
    with open(in_file, 'r') as inputFile, open(out_file, 'w') as outputFile:
        outputFile.write("@00000000\n")
        
        lines_written = 0
        MAX_INSTRUCTIONS = 1024

        for line in inputFile:
            if lines_written >= MAX_INSTRUCTIONS:
                break
                
            clean_line = line.split()[0].strip()
            if clean_line and not clean_line.startswith('@'):
                outputFile.write(clean_line + "\n")
                lines_written += 1
                
    print(f"Done! Created {out_file} for updatemem. Total words: {lines_written}/{MAX_INSTRUCTIONS}")

bin_to_hex_with_bootloader("imem.bin", "imem.hex")
bin2hex("dmem.bin", "dmem.hex")
# time.sleep(10)
hex2mem("imem.hex", "imem.mem")
hex2mem("dmem.hex", "dmem.mem")
