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
        f_out.write("@00000000\n")
        
        for line in f_in:
            # 2. Strip anything after // (the comments you showed me)
            clean_line = line.split("//")[0].strip()
            
            # 3. Only write if the line isn't empty
            if clean_line:
                # updatemem expects the 8-character hex string as TEXT
                f_out.write(clean_line + "\n")

    print(f"Done! Created {out_file} for updatemem.")

bin2hex("imem.bin", "imem.hex")
bin2hex("dmem.bin", "dmem.hex")
# time.sleep(10)
hextomem("imem.hex", "imem.mem")
hextomem("dmem.hex", "dmem.mem")
