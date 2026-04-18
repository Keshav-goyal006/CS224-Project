import serial
import numpy as np
import matplotlib.pyplot as plt

if not hasattr(serial, "Serial"):
    raise SystemExit(
        "PySerial is not the serial module being imported. Remove the 'serial' package and reinstall pyserial: "
        "py -m pip uninstall -y serial && py -m pip install --force-reinstall pyserial"
    )

# --- CONFIGURATION ---
# Change this to match your Device Manager / Terminal!
COM_PORT = 'COM8' 
BAUD_RATE = 115200

# Your C code generates a 160x120 image
WIDTH = 64
HEIGHT = 48
TOTAL_PIXELS = WIDTH * HEIGHT

print(f"Listening on {COM_PORT} at {BAUD_RATE} baud...")
print("-> PRESS THE RESET BUTTON ON YOUR FPGA NOW <-")

try:
    # Open the serial port
    with serial.Serial(COM_PORT, BAUD_RATE, timeout=30) as ser:
        
        print("Waiting for data...")
        raw_data = ser.read(TOTAL_PIXELS)
        
        if len(raw_data) == TOTAL_PIXELS:
            print("All 19,200 pixels received successfully!")
            
            # Convert the raw bytes into a NumPy array
            image_array = np.frombuffer(raw_data, dtype=np.uint8)
            
            # Reshape it into a 2D grid (120 rows by 160 columns)
            image_2d = image_array.reshape((HEIGHT, WIDTH))
            
            # Draw the image
            plt.imshow(image_2d, cmap='gray', vmin=0, vmax=255)
            plt.title("Hardware Accelerated Output from Nexys A7")
            plt.axis('off')
            plt.show()
        else:
            print(f"Error: Only received {len(raw_data)} out of {TOTAL_PIXELS} pixels.")
            print("Did you forget to reset the board?")

except Exception as e:
    print(f"Failed to connect: {e}")