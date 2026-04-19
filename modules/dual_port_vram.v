`timescale 1ns / 1ps

module dual_port_vram (
    input wire clk,
    
    // Port A: CPU write port
    input wire we_a,
    input wire [3:0] wstrb_a,
    input wire [15:0] addr_a, // 256 * 192 = 49152 addresses
    input wire [31:0] din_a,  // 0x00RRGGBB
    
    // Port B: VGA Controller (Read Only)
    input wire [15:0] addr_b,
    output reg [23:0] dout_b
);

    // 24-bit RGB VRAM
    (* ram_style = "block" *) 
    reg [23:0] ram [0:49151];

    // Initialize VRAM to black.
    integer i;
    initial begin
        for (i = 0; i < 49152; i = i + 1) begin
            ram[i] = 24'h000000;
        end
    end

    always @(posedge clk) begin
        // CPU writes to Port A
        if (we_a && (addr_a < 49152)) begin
            if (wstrb_a[0]) ram[addr_a][7:0]   <= din_a[7:0];
            if (wstrb_a[1]) ram[addr_a][15:8]  <= din_a[15:8];
            if (wstrb_a[2]) ram[addr_a][23:16] <= din_a[23:16];
        end

        // VGA constantly reads from Port B
        if (addr_b < 49152) begin
            dout_b <= ram[addr_b];
        end else begin
            dout_b <= 24'h000000;
        end
    end

endmodule