# generates vram_init.hex for a 160x120 8-bit display
WIDTH = 160
HEIGHT = 120

with open('vram_init.hex', 'w') as f:
    for y in range(HEIGHT):
        for x in range(WIDTH):
            # Create a cool gradient pattern!
            # X determines the brightness, Y creates horizontal bands
            pixel_val = (x + y) % 256
            
            # Write as a 2-digit Hex number (e.g., "FF\n")
            f.write(f"{pixel_val:02X}\n")

print("Success! vram_init.hex created with 19,200 pixels.")