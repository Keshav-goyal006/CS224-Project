`timescale 1ns / 1ps

module dual_port_vram #(
    parameter integer PIXEL_COUNT = 19200,
    parameter integer ADDR_WIDTH  = 15
)(
    input wire clk,

    // Port A: CPU write port
    input wire we_a,
    input wire [ADDR_WIDTH-1:0] addr_a,
    input wire [7:0] din_a,

    // Port B: VGA read port
    input wire [ADDR_WIDTH-1:0] addr_b,
    output reg [7:0] dout_b
);

    (* ram_style = "block" *)
    reg [7:0] ram [0:PIXEL_COUNT-1];

    integer i;
    initial begin
        for (i = 0; i < PIXEL_COUNT; i = i + 1) begin
            ram[i] = 8'h00;
        end
    end

    always @(posedge clk) begin
        if (we_a && (addr_a < PIXEL_COUNT)) begin
            ram[addr_a] <= din_a;
        end

        if (addr_b < PIXEL_COUNT) begin
            dout_b <= ram[addr_b];
        end else begin
            dout_b <= 8'h00;
        end
    end

endmodule