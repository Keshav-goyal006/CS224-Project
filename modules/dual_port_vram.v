`timescale 1ns / 1ps

module dual_port_vram (
    input wire clk,
    
    // Port A: CPU (Write Only for this demo)
    input wire we_a,
    input wire [15:0] addr_a, // 256 * 192 = 49152 addresses
    input wire [7:0] din_a,   // 8-bit grayscale pixel
    
    // Port B: VGA Controller (Read Only)
    input wire [15:0] addr_b,
    output reg [7:0] dout_b
);

    // Tell Vivado explicitly to use physical Block RAM, not logic gates
    (* ram_style = "block" *) 
    reg [7:0] ram [0:49151];

    // Initialize to black
    // Initialize VRAM with our static image
    initial begin
        // Make sure vram_init.hex is added to your Vivado project sources!
        $readmemh("vram_init.hex", ram);
    end

    always @(posedge clk) begin
        // CPU writes to Port A
        if (we_a) begin
            ram[addr_a] <= din_a;
        end
        // VGA constantly reads from Port B
        dout_b <= ram[addr_b];
    end

endmodule