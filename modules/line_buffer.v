`timescale 1ns / 1ps

module line_buffer #(
    parameter WIDTH = 64 // Change to 160 if doing 160x120 images!
)(
    input  wire clk,
    input  wire reset,
    input  wire en,         // Shift enable
    input  wire [7:0] din,  // Pixel entering
    output wire [7:0] dout  // Pixel exiting (delayed by exactly 1 row)
);

    // Create an array of registers to hold one full row of pixels
    reg [7:0] shift_reg [0:WIDTH-1];
    integer i;

    // The oldest pixel falls out the end
    assign dout = shift_reg[WIDTH-1];

    always @(posedge clk) begin
        if (!reset) begin
            for (i = 0; i < WIDTH; i = i + 1) begin
                shift_reg[i] <= 8'h00;
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