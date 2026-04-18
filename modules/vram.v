`timescale 1ns / 1ps

module dual_port_vram #(
    parameter integer PIXEL_COUNT = 49152,
    parameter integer ADDR_WIDTH  = 15
)(
    input wire clk,

    // Port A: CPU write port
    input wire we_a,
    input wire [3:0] wstrb_a,
    input wire [ADDR_WIDTH-1:0] addr_a,
    input wire [31:0] din_a,

    // Port B: VGA read port
    input wire [ADDR_WIDTH-1:0] addr_b,
    output reg [23:0] dout_b
);

    (* ram_style = "block" *)
    reg [23:0] ram [0:PIXEL_COUNT-1];

    integer i;
    initial begin
        for (i = 0; i < PIXEL_COUNT; i = i + 1) begin
            ram[i] = 8'h00;
        end
    end

    always @(posedge clk) begin
        if (we_a && (addr_a < PIXEL_COUNT)) begin
            if (wstrb_a[0]) ram[addr_a][7:0]   <= din_a[7:0];
            if (wstrb_a[1]) ram[addr_a][15:8]  <= din_a[15:8];
            if (wstrb_a[2]) ram[addr_a][23:16] <= din_a[23:16];
        end

        if (addr_b < PIXEL_COUNT) begin
            dout_b <= ram[addr_b];
        end else begin
            dout_b <= 24'h000000;
        end
    end

endmodule