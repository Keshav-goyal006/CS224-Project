import serial
import time
import sys
import numpy as np
import matplotlib.pyplot as plt

# --- Configuration ---
COM_PORT = 'COM8'
BAUD_RATE = 115200
IMAGE_SIZE = 3072  # 32x32 pixels * 3 channels (RGB)
INPUT_FILE = 'input_image.bin' 

def run_transceiver():
    print(f"--- RISC-V UART Transceiver ---")
    print(f"Opening {COM_PORT} at {BAUD_RATE} baud...\n")
    
    try:
        ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=5)
        time.sleep(1) 
        
        # ==========================================
        # PHASE 1: TRANSMIT (PC -> FPGA)
        # ==========================================
        try:
            with open(INPUT_FILE, 'rb') as f:
                tx_data = f.read()
        except FileNotFoundError:
            print(f"[ERROR] Could not find {INPUT_FILE}!")
            sys.exit(1)
            
        if len(tx_data) != IMAGE_SIZE:
            print(f"[WARNING] File is {len(tx_data)} bytes. FPGA expects {IMAGE_SIZE} bytes.")
            
        print(f"[TX] Sending {len(tx_data)} bytes to the FPGA...")
        start_time = time.time()
        
        # FIX: Send in chunks of 32 bytes to prevent overflowing the FPGA's UART FIFO
        chunk_size = 32
        for i in range(0, len(tx_data), chunk_size):
            ser.write(tx_data[i:i+chunk_size])
            # A tiny sleep gives the RISC-V CPU time to process the pixels
            time.sleep(0.005) 
            
        ser.flush() 
        print(f"[TX] Upload complete in {time.time() - start_time:.2f} seconds.")
        print("-" * 40)
        
        # ==========================================
        # PHASE 2: RECEIVE (FPGA -> PC)
        # ==========================================
        print("[RX] Waiting for the Accelerator to process and respond...")
        rx_data = bytearray()
        
        while len(rx_data) < IMAGE_SIZE:
            chunk = ser.read(IMAGE_SIZE - len(rx_data))
            
            if not chunk:
                print(f"\n[ERROR] Timeout! Only received {len(rx_data)} / {IMAGE_SIZE} bytes.")
                break
                
            rx_data.extend(chunk)
            print(f"\r[RX] Received: {len(rx_data)} / {IMAGE_SIZE} bytes...", end="")
            
        print("\n" + "-" * 40)
        
        # ==========================================
        # PHASE 3: DISPLAY RESULTS (POPUP)
        # ==========================================
        if len(rx_data) == IMAGE_SIZE:
            print("[SUCCESS] Processing complete. Opening image viewer...")
            
            # 1. Convert raw bytes to an array of 8-bit integers
            img_array = np.frombuffer(rx_data, dtype=np.uint8)
            
            try:
                # 2. Reshape into a 32x32 RGB image matrix
                # If your dimensions are different, adjust (Height, Width, Channels)
                img_matrix = img_array.reshape((32, 32, 3))
                
                # 3. Render the popup window
                plt.imshow(img_matrix)
                plt.title("FPGA Hardware Convoluter Output")
                plt.axis('off') # Hide the graph axes
                plt.show()      # Halts the script and displays the window
                
            except ValueError as e:
                print(f"[ERROR] Could not reshape image array: {e}")
                print("Make sure IMAGE_SIZE correctly matches Height * Width * Channels.")
            
    except serial.SerialException as e:
        print(f"\n[ERROR] Serial Port Issue: {e}")
        print("Check if Vivado Hardware Manager is keeping the port busy!")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print("Port closed.")

if __name__ == "__main__":
    run_transceiver()