import serial
import time
import os
import struct

def parse_hex_to_binary(file_path):
    """Reads a Verilog-style hex file and converts it to raw binary bytes (Little Endian)."""
    print("Detected .hex/.mem file. Converting to raw binary on the fly...")
    binary_data = bytearray()
    
    with open(file_path, 'r') as f:
        for line in f:
            # Strip comments (supports both // and #)
            line = line.split('//')[0].split('#')[0].strip()
            if not line:
                continue
            
            # Split by whitespace in case there are multiple words on one line
            words = line.split()
            for word in words:
                # Ignore @ address markers 
                if word.startswith('@'):
                    continue
                
                try:
                    val = int(word, 16)
                    # Pack as 32-bit unsigned integer, Little-Endian ('<I')
                    packed_bytes = struct.pack('<I', val)
                    binary_data.extend(packed_bytes)
                except ValueError:
                    print(f"Warning: Could not parse '{word}' as hex. Skipping.")
                    
    return bytes(binary_data)

def send_file(com_port, file_path, baud_rate=115200):
    try:
        if not os.path.exists(file_path):
            print(f"Error: File '{file_path}' not found.")
            return

        print(f"Opening {com_port} at {baud_rate} baud...")

        # 1. Prepare the data (Handle binary vs hex)
        file_ext = os.path.splitext(file_path)[1].lower()
        if file_ext in ['.hex', '.mem']:
            data = parse_hex_to_binary(file_path)
        else:
            with open(file_path, 'rb') as f:
                data = f.read()

        # 2. Match the current bootloader payload: 0x1400..0x1fff.
        RAMSIZE = 3072
        if len(data) < RAMSIZE:
            print(f"Padding file from {len(data)} bytes to {RAMSIZE} bytes with zeros...")
            data += b'\x00' * (RAMSIZE - len(data))
        elif len(data) > RAMSIZE:
            print(f"Warning: File is larger than {RAMSIZE} bytes! Truncating...")
            data = data[:RAMSIZE]

        file_size = len(data)
        print(f"Total payload size: {file_size} bytes ({file_size // 4} 32-bit words)")

        # 3. Open the serial port
        ser = serial.Serial(com_port, baud_rate, timeout=2)
        
        # 4. Send the data
        print("Sending data to FPGA...")
        start_time = time.time()
        
        chunk_size = 64 
        bytes_sent = 0
        
        for i in range(0, len(data), chunk_size):
            chunk = data[i:i+chunk_size]
            ser.write(chunk)
            bytes_sent += len(chunk)
            
            # Progress bar
            progress = (bytes_sent / file_size) * 100
            print(f"\rProgress: [{bytes_sent}/{file_size} bytes] {progress:.1f}%", end="")
            
            # Tiny delay to prevent overwhelming the unbuffered hardware RX
            time.sleep(0.005)
        
        ser.flush() 
        end_time = time.time()
        
        print(f"\n\nUpload complete! Took {end_time - start_time:.2f} seconds.")
        print("You can now flip Switch 15 DOWN to start the image convolution.")
            
    except serial.SerialException as e:
        print(f"\nSerial Error: Could not connect to {com_port}. Is it open in another program?")
        print(f"Details: {e}")
    except Exception as e:
        print(f"\nAn unexpected error occurred: {e}")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()

if __name__ == "__main__":
    # --- HARDCODED VARIABLES ---
    TARGET_PORT = "COM8"
    TARGET_FILE = "input_image.bin"  # Change this to your .bin, .hex, or .mem file path
    
    send_file(TARGET_PORT, TARGET_FILE)
