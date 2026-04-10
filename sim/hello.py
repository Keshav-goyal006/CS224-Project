import serial

SERIAL_PORT = 'COM8' # Make sure this is correct
BAUD_RATE = 115200

print(f"Listening on {SERIAL_PORT}...")
print("Press the CPU_RESET button on the FPGA!\n")

try:
    ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=None)
    
    while True:
        # Read raw bytes and decode them into English text
        data = ser.read(1)
        if data:
            print(data.decode('ascii', errors='ignore'), end='', flush=True)

except serial.SerialException as e:
    print(f"\n[Error] USB disconnected! Vivado or Windows killed the port.")
finally:
    if 'ser' in locals() and ser.is_open:
        ser.close()