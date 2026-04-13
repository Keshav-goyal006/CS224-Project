import serial
import time
import os
import struct

def parse_hex_to_binary(file_path):
    print("Detected .hex/.mem file. Converting to raw binary on the fly...")
    binary_data = bytearray()
    with open(file_path, 'r') as f:
        for line in f:
            line = line.split('//')[0].split('#')[0].strip()
            if not line: continue
            words = line.split()
            for word in words:
                if word.startswith('@'): continue
                try:
                    val = int(word, 16)
                    packed_bytes = struct.pack('<I', val)
                    binary_data.extend(packed_bytes)
                except ValueError:
                    pass
    return bytes(binary_data)

def run_convolution(com_port, input_file, output_file, baud_rate=115200):
    ser = None
    try:
        # 1. Prepare the Input Data
        if not os.path.exists(input_file):
            print(f"Error: File '{input_file}' not found.")
            return

        file_ext = os.path.splitext(input_file)[1].lower()
        if file_ext in ['.hex', '.mem']:
            data = parse_hex_to_binary(input_file)
        else:
            with open(input_file, 'rb') as f:
                data = f.read()

        # The current bootloader fills 0x1400..0x1fff, the 3072-byte image area.
        RAMSIZE = 3072
        if len(data) < RAMSIZE:
            data += b'\x00' * (RAMSIZE - len(data))
        elif len(data) > RAMSIZE:
            data = data[:RAMSIZE]

        # 2. Open Port (Exclusive Lock)
        print(f"Opening {com_port} at {baud_rate} baud...")
        # Note: No timeout! It will wait forever for the FPGA to process the image.
        ser = serial.Serial(com_port, baud_rate)

        # 3. Phase 1: Send the Image
        print(f"Sending {len(data)} bytes to Bootloader...")
        chunk_size = 64 
        bytes_sent = 0
        
        for i in range(0, len(data), chunk_size):
            chunk = data[i:i+chunk_size]
            ser.write(chunk)
            bytes_sent += len(chunk)
            print(f"\rProgress: [{bytes_sent}/{len(data)} bytes]", end="")
            time.sleep(0.005)
            
        ser.flush()
        print("\n\n*** UPLOAD COMPLETE! ***")
        print(">>> FLIP SWITCH 15 DOWN NOW TO START CONVOLUTION <<<")

        # 4. Phase 2: Wait for the Output
        EXPECTED_BYTES = 3072
        print(f"\nListening for {EXPECTED_BYTES} processed bytes...")
        
        # This will block and wait until you flip the switch and the FPGA sends the data
        received_data = ser.read(EXPECTED_BYTES)

        # 5. Save the Output
        with open(output_file, 'wb') as f:
            f.write(received_data)
            
        print(f"\nSUCCESS! Caught {len(received_data)} bytes.")
        print(f"Saved processed image to: {output_file}")

    except Exception as e:
        print(f"\nError: {e}")
    finally:
        if ser and ser.is_open:
            ser.close()
            print("Port closed.")

if __name__ == "__main__":
    TARGET_PORT = "COM8"
    INPUT_FILE = "input_image.bin"  
    OUTPUT_FILE = "processed_image.bin" 
    
    run_convolution(TARGET_PORT, INPUT_FILE, OUTPUT_FILE)
