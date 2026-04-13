import serial
import time
import sys

# --- Configuration ---
COM_PORT = 'COM8'
BAUD_RATE = 115200
IMAGE_SIZE = 3072  # The exact number of bytes your Accelerator expects
# INPUT_FILE = 'imem_dmem/dmem.bin'
INPUT_FILE = 'input_image.bin'  # This should be the output from convert_h_to_bin.py
OUTPUT_FILE = 'processed_image.bin'

def run_transceiver():
    print(f"--- RISC-V UART Transceiver ---")
    print(f"Opening {COM_PORT} at {BAUD_RATE} baud...\n")
    
    try:
        # Open the serial port with a timeout
        # Timeout is crucial so the script doesn't hang forever if the FPGA dies
        ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=5)
        time.sleep(1) # Brief pause to let the OS stabilize the port
        
        # ==========================================
        # PHASE 1: TRANSMIT (PC -> FPGA)
        # ==========================================
        try:
            with open(INPUT_FILE, 'rb') as f:
                tx_data = f.read()
        except FileNotFoundError:
            print(f"[ERROR] Could not find {INPUT_FILE}!")
            print("To test the loop, create a dummy file of exactly 3072 bytes.")
            sys.exit(1)
            
        if len(tx_data) != IMAGE_SIZE:
            print(f"[WARNING] File is {len(tx_data)} bytes. FPGA expects exactly {IMAGE_SIZE} bytes.")
            
        print(f"[TX] Sending {len(tx_data)} bytes to the FPGA...")
        start_time = time.time()
        
        ser.write(tx_data)
        ser.flush() # Force the OS to push every byte out of the USB buffer
        
        print(f"[TX] Upload complete in {time.time() - start_time:.2f} seconds.")
        print("-" * 40)
        
        # ==========================================
        # PHASE 2: RECEIVE (FPGA -> PC)
        # ==========================================
        print("[RX] Waiting for the Accelerator to process and respond...")
        
        rx_data = bytearray()
        
        # Keep reading until we get the exact number of expected bytes
        while len(rx_data) < IMAGE_SIZE:
            # Read whatever is currently sitting in the buffer
            chunk = ser.read(IMAGE_SIZE - len(rx_data))
            
            if not chunk:
                # If chunk is empty, the 5-second timeout hit.
                print(f"\n[ERROR] Timeout! Only received {len(rx_data)} / {IMAGE_SIZE} bytes.")
                print("Did the FPGA freeze, or is it stuck in the bootloader loop?")
                break
                
            rx_data.extend(chunk)
            
            # Print a little progress tracker to the console
            print(f"\r[RX] Received: {len(rx_data)} / {IMAGE_SIZE} bytes...", end="")
            
        print("\n" + "-" * 40)
        
        # ==========================================
        # PHASE 3: SAVE RESULTS
        # ==========================================
        if len(rx_data) > 0:
            with open(OUTPUT_FILE, 'wb') as f:
                f.write(rx_data)
            print(f"[SUCCESS] Saved output to {OUTPUT_FILE}")
            
    except serial.SerialException as e:
        print(f"\n[ERROR] Serial Port Issue: {e}")
        print("Check if Vivado Hardware Manager is keeping the port busy!")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print("Port closed.")

if __name__ == "__main__":
    run_transceiver()