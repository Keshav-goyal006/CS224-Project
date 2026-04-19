from PIL import Image

def generate_virtual_monitor(filename="vga_dump.txt", width=640, height=480):
    print("Generating image from simulation data...")
    # Create a blank black canvas
    img = Image.new('RGB', (width, height), "black")
    pixels = img.load()

    try:
        with open(filename, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) == 5:
                    x, y, r, g, b = map(int, parts)
                    # Protect against out-of-bounds writes
                    if 0 <= x < width and 0 <= y < height:
                        pixels[x, y] = (r, g, b)
                        
        img.save("vga_output.png")
        print("Success! Check vga_output.png")
    except FileNotFoundError:
        print(f"Error: Could not find {filename}. Run your Verilog testbench first.")

if __name__ == "__main__":
    generate_virtual_monitor()