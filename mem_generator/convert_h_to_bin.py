import re

# --- Configuration ---
H_FILE = 'image_data.h'          # Make sure this matches your file name!
BIN_FILE = 'input_image.bin' 
EXPECTED_SIZE = 3072

def convert_h_to_bin():
    print(f"Reading {H_FILE}...")
    
    try:
        with open(H_FILE, 'r') as f:
            content = f.read()
            
        # 1. Isolate the data: Find everything strictly between { and }
        array_match = re.search(r'\{(.*?)\}', content, re.DOTALL)
        
        if not array_match:
            print("[ERROR] Could not find the { } brackets in the file.")
            return
            
        array_content = array_match.group(1)
        
        # 2. Extract only the digits from inside the brackets
        # This safely ignores the 64, 48, and 3072 at the top of your file
        str_numbers = re.findall(r'\d+', array_content)
        
        # 3. Convert strings to integers
        byte_list = [int(num) for num in str_numbers]
            
        print(f"Extracted {len(byte_list)} pixels from the array.")
        
        if len(byte_list) != EXPECTED_SIZE:
            print(f"[WARNING] Expected {EXPECTED_SIZE} bytes, but got {len(byte_list)}.")
            
        # 4. Save as a raw binary file
        with open(BIN_FILE, 'wb') as f:
            f.write(bytearray(byte_list))
            
        print(f"Success! Created {BIN_FILE}. Ready for UART transmission!")
        
    except FileNotFoundError:
        print(f"Error: Could not find {H_FILE}")

if __name__ == "__main__":
    convert_h_to_bin()