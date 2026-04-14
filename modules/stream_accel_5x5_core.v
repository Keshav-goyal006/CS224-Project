`timescale 1ns / 1ps

module stream_accel_5x5_core #(
    parameter IMG_WIDTH = 256
)(
    input  wire clk,
    input  wire reset,

    // Streaming input
    input  wire [7:0] pixel_in,
    input  wire       pixel_valid,

    // Control (same as your switches)
    input  wire [3:0] switches,

    // Streaming output
    output wire [7:0] pixel_out,
    output wire       pixel_valid_out
);

    // --------------------------------------------------------
    // 1. 5x5 Window Registers
    // --------------------------------------------------------
    reg signed [31:0] p00, p01, p02, p03, p04;
    reg signed [31:0] p10, p11, p12, p13, p14;
    reg signed [31:0] p20, p21, p22, p23, p24;
    reg signed [31:0] p30, p31, p32, p33, p34;
    reg signed [31:0] p40, p41, p42, p43, p44;

    // --------------------------------------------------------
    // 2. Line Buffers
    // --------------------------------------------------------
    wire [7:0] row3_pixel, row2_pixel, row1_pixel, row0_pixel;

    line_buffer #(.WIDTH(IMG_WIDTH)) LB1 (.clk(clk), .reset(reset), .en(pixel_valid), .din(pixel_in),    .dout(row3_pixel));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB2 (.clk(clk), .reset(reset), .en(pixel_valid), .din(row3_pixel),  .dout(row2_pixel));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB3 (.clk(clk), .reset(reset), .en(pixel_valid), .din(row2_pixel),  .dout(row1_pixel));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB4 (.clk(clk), .reset(reset), .en(pixel_valid), .din(row1_pixel),  .dout(row0_pixel));

    // --------------------------------------------------------
    // 3. Shift Window
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (!reset) begin
            p00<=0; p01<=0; p02<=0; p03<=0; p04<=0;
            p10<=0; p11<=0; p12<=0; p13<=0; p14<=0;
            p20<=0; p21<=0; p22<=0; p23<=0; p24<=0;
            p30<=0; p31<=0; p32<=0; p33<=0; p34<=0;
            p40<=0; p41<=0; p42<=0; p43<=0; p44<=0;
        end else if (pixel_valid) begin
            p00<=p01; p01<=p02; p02<=p03; p03<=p04; p04<=row0_pixel;
            p10<=p11; p11<=p12; p12<=p13; p13<=p14; p14<=row1_pixel;
            p20<=p21; p21<=p22; p22<=p23; p23<=p24; p24<=row2_pixel;
            p30<=p31; p31<=p32; p32<=p33; p33<=p34; p34<=row3_pixel;
            p40<=p41; p41<=p42; p42<=p43; p43<=p44; p44<=pixel_in;
        end
    end

    // --------------------------------------------------------
    // 4. Kernel ROM (same as yours)
    // --------------------------------------------------------
    reg signed [31:0] w00, w01, w02, w03, w04;
    reg signed [31:0] w10, w11, w12, w13, w14;
    reg signed [31:0] w20, w21, w22, w23, w24;
    reg signed [31:0] w30, w31, w32, w33, w34;
    reg signed [31:0] w40, w41, w42, w43, w44;

    reg [3:0] shift_val;
    reg abs_val_enable;

    always @(*) begin
        case(switches)
            4'b0001: begin
                w00=1; w01=4;  w02=6;  w03=4;  w04=1;
                w10=4; w11=16; w12=24; w13=16; w14=4;
                w20=6; w21=24; w22=36; w23=24; w24=6;
                w30=4; w31=16; w32=24; w33=16; w34=4;
                w40=1; w41=4;  w42=6;  w43=4;  w44=1;
                shift_val = 8;
                abs_val_enable = 0;
            end
            default: begin
                w00=0; w01=0; w02=0; w03=0; w04=0;
                w10=0; w11=0; w12=0; w13=0; w14=0;
                w20=0; w21=0; w22=1; w23=0; w24=0;
                w30=0; w31=0; w32=0; w33=0; w34=0;
                w40=0; w41=0; w42=0; w43=0; w44=0;
                shift_val = 0;
                abs_val_enable = 0;
            end
        endcase
    end

    // --------------------------------------------------------
    // 5. MAC
    // --------------------------------------------------------
    wire signed [31:0] raw_mac =
        (p00*w00)+(p01*w01)+(p02*w02)+(p03*w03)+(p04*w04)+
        (p10*w10)+(p11*w11)+(p12*w12)+(p13*w13)+(p14*w14)+
        (p20*w20)+(p21*w21)+(p22*w22)+(p23*w23)+(p24*w24)+
        (p30*w30)+(p31*w31)+(p32*w32)+(p33*w33)+(p34*w34)+
        (p40*w40)+(p41*w41)+(p42*w42)+(p43*w43)+(p44*w44);

    wire signed [31:0] shifted = raw_mac >>> shift_val;
    wire signed [31:0] abs_val = (abs_val_enable && shifted < 0) ? -shifted : shifted;

    wire [7:0] final_pixel =
        (abs_val < 0)   ? 8'd0   :
        (abs_val > 255) ? 8'd255 :
                          abs_val[7:0];

    // --------------------------------------------------------
    // 6. Output
    // --------------------------------------------------------
    reg valid_d;

    always @(posedge clk) begin
        if (!reset)
            valid_d <= 0;
        else
            valid_d <= pixel_valid;
    end

    assign pixel_out       = final_pixel;
    assign pixel_valid_out = valid_d;

endmodule