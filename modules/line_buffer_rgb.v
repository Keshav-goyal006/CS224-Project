`timescale 1ns / 1ps

module line_buffer_rgb #(
    parameter WIDTH = 128,
    parameter DATA_WIDTH = 24 // Added to support RGB!
)(
    input wire clk,
    input wire reset,
    input wire en,
    input wire [DATA_WIDTH-1:0] din,
    output wire [DATA_WIDTH-1:0] dout
);

    // Create an array of registers to hold one full row of pixels
    reg [DATA_WIDTH-1:0] shift_reg [0:WIDTH-1];
    integer i;

    // The oldest pixel falls out the end
    assign dout = shift_reg[WIDTH-1];

    always @(posedge clk) begin
        if (!reset) begin
            for (i = 0; i < WIDTH; i = i + 1) begin
                shift_reg[i] <= 0;
            end
        end else if (en) begin
            // Shift everything to the right
            for (i = WIDTH-1; i > 0; i = i - 1) begin
                shift_reg[i] <= shift_reg[i-1];
            end
            // Feed the new pixel into the front
            shift_reg[0] <= din;
        end
    end

endmodule