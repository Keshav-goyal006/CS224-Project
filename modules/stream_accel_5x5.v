`timescale 1ns / 1ps

module stream_accel_5x5 #(
    parameter IMG_WIDTH = 64
)(
    input  wire clk,
    input  wire reset,
    input  wire [3:0] switches, // 4-bit switch input from Top Module
    
    // CPU Interface
    input  wire        we,
    input  wire [31:0] waddr,
    input  wire [31:0] wdata,
    input  wire [31:0] raddr,
    output reg  [31:0] rdata
);

    // --------------------------------------------------------
    // 1. The 5x5 Window Registers (25 Pixels!)
    // --------------------------------------------------------
    reg signed [31:0] p00, p01, p02, p03, p04; // Row 0
    reg signed [31:0] p10, p11, p12, p13, p14; // Row 1
    reg signed [31:0] p20, p21, p22, p23, p24; // Row 2 (Center)
    reg signed [31:0] p30, p31, p32, p33, p34; // Row 3
    reg signed [31:0] p40, p41, p42, p43, p44; // Row 4 (Live)

    // --------------------------------------------------------
    // 2. The 4 Line Buffers
    // --------------------------------------------------------
    wire [7:0] row3_pixel, row2_pixel, row1_pixel, row0_pixel;
    wire pixel_push = we && (waddr == 32'h00002024);

    line_buffer #(.WIDTH(IMG_WIDTH)) LB1 (.clk(clk), .reset(reset), .en(pixel_push), .din(wdata[7:0]),  .dout(row3_pixel));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB2 (.clk(clk), .reset(reset), .en(pixel_push), .din(row3_pixel),  .dout(row2_pixel));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB3 (.clk(clk), .reset(reset), .en(pixel_push), .din(row2_pixel),  .dout(row1_pixel));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB4 (.clk(clk), .reset(reset), .en(pixel_push), .din(row1_pixel),  .dout(row0_pixel));

    // --------------------------------------------------------
    // 3. Shift Window Logic
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (!reset) begin // ACTIVE LOW RESET!
            p00<=0; p01<=0; p02<=0; p03<=0; p04<=0;
            p10<=0; p11<=0; p12<=0; p13<=0; p14<=0;
            p20<=0; p21<=0; p22<=0; p23<=0; p24<=0;
            p30<=0; p31<=0; p32<=0; p33<=0; p34<=0;
            p40<=0; p41<=0; p42<=0; p43<=0; p44<=0;
        end else if (pixel_push) begin
            p00<=p01; p01<=p02; p02<=p03; p03<=p04; p04<=row0_pixel;
            p10<=p11; p11<=p12; p12<=p13; p13<=p14; p14<=row1_pixel;
            p20<=p21; p21<=p22; p22<=p23; p23<=p24; p24<=row2_pixel;
            p30<=p31; p31<=p32; p32<=p33; p33<=p34; p34<=row3_pixel;
            p40<=p41; p41<=p42; p42<=p43; p43<=p44; p44<=wdata[7:0];
        end
    end

    // --------------------------------------------------------
    // 4. HARDWARE KERNEL ROM (Switch Controlled)
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
            4'b0001: begin // Switch 0: 5x5 GAUSSIAN BLUR (Sum = 256)
                w00=1; w01=4;  w02=6;  w03=4;  w04=1;
                w10=4; w11=16; w12=24; w13=16; w14=4;
                w20=6; w21=24; w22=36; w23=24; w24=6;
                w30=4; w31=16; w32=24; w33=16; w34=4;
                w40=1; w41=4;  w42=6;  w43=4;  w44=1;
                shift_val = 8; // Divide by 256
                abs_val_enable = 0;
            end
            4'b0010: begin // Switch 1: 5x5 EDGE DETECT (Sum = 0)
                w00=-1; w01=-1; w02=-1; w03=-1; w04=-1;
                w10=-1; w11=-1; w12=-1; w13=-1; w14=-1;
                w20=-1; w21=-1; w22=24; w23=-1; w24=-1;
                w30=-1; w31=-1; w32=-1; w33=-1; w34=-1;
                w40=-1; w41=-1; w42=-1; w43=-1; w44=-1;
                shift_val = 0; // No division
                abs_val_enable = 1; // Needs Absolute Value
            end
            4'b1000: begin // Switch combination 8: UNSHARP MASK (Sum = 8)
                w00=-1; w01=-1; w02=-1; w03=-1; w04=-1;
                w10=-1; w11=-1; w12=-1; w13=-1; w14=-1;
                w20=-1; w21=-1; w22=32; w23=-1; w24=-1;
                w30=-1; w31=-1; w32=-1; w33=-1; w34=-1;
                w40=-1; w41=-1; w42=-1; w43=-1; w44=-1;
                shift_val = 3; // Divide by 8
                abs_val_enable = 0;
            end
            4'b0011: begin // Switch combination 3: DIAGONAL MOTION BLUR (Sum = 8)
                w00=1; w01=0; w02=0; w03=0; w04=0;
                w10=0; w11=2; w12=0; w13=0; w14=0;
                w20=0; w21=0; w22=2; w23=0; w24=0;
                w30=0; w31=0; w32=0; w33=2; w34=0;
                w40=0; w41=0; w42=0; w43=0; w44=1;
                shift_val = 3; // Divide by 8
                abs_val_enable = 0;
            end
            4'b0101: begin // Switch combination 5: LAPLACIAN OF GAUSSIAN (Sum = 0)
                w00=0;  w01=0;  w02=-1; w03=0;  w04=0;
                w10=0;  w11=-1; w12=-2; w13=-1; w14=0;
                w20=-1; w21=-2; w22=16; w23=-2; w24=-1;
                w30=0;  w31=-1; w32=-2; w33=-1; w34=0;
                w40=0;  w41=0;  w42=-1; w43=0;  w44=0;
                shift_val = 0; // No division
                abs_val_enable = 1; // Needs Absolute Value
            end
            4'b0110: begin // Switch combination 6: 3D EMBOSS (Sum = 1)
                w00=-2; w01=-1; w02=0; w03=0; w04=0;
                w10=-1; w11=-1; w12=0; w13=0; w14=0;
                w20=0;  w21=0;  w22=1; w23=0; w24=0;
                w30=0;  w31=0;  w32=0; w33=1; w34=1;
                w40=0;  w41=0;  w42=0; w43=1; w44=2;
                shift_val = 0; // Divide by 1
                abs_val_enable = 0;
            end
            4'b0111: begin // Switch combination 7: DISK BLUR (Sum = 32)
                w00=1; w01=1; w02=1; w03=1; w04=1;
                w10=1; w11=1; w12=2; w13=1; w14=1;
                w20=1; w21=2; w22=4; w23=2; w24=1;
                w30=1; w31=1; w32=2; w33=1; w34=1;
                w40=1; w41=1; w42=1; w43=1; w44=1;
                shift_val = 5; // Divide by 32
                abs_val_enable = 0;
            end
            4'b0100: begin // Switch 2: 5x5 SHARPEN (Sum = 16)
                w00=0;  w01=0;  w02=-2; w03=0;  w04=0;
                w10=0;  w11=-2; w12=-4; w13=-2; w14=0;
                w20=-2; w21=-4; w22=48; w23=-4; w24=-2;
                w30=0;  w31=-2; w32=-4; w33=-2; w34=0;
                w40=0;  w41=0;  w42=-2; w43=0;  w44=0;
                shift_val = 4; // Divide by 16
                abs_val_enable = 0;
            end
            default: begin // Default: IDENTITY (Pass-through)
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
    // 5. THE 25-MULTIPLIER MATH ENGINE
    // --------------------------------------------------------
    wire signed [31:0] raw_mac = 
        (p00 * w00) + (p01 * w01) + (p02 * w02) + (p03 * w03) + (p04 * w04) +
        (p10 * w10) + (p11 * w11) + (p12 * w12) + (p13 * w13) + (p14 * w14) +
        (p20 * w20) + (p21 * w21) + (p22 * w22) + (p23 * w23) + (p24 * w24) +
        (p30 * w30) + (p31 * w31) + (p32 * w32) + (p33 * w33) + (p34 * w34) +
        (p40 * w40) + (p41 * w41) + (p42 * w42) + (p43 * w43) + (p44 * w44);

    // Apply Bit-Shift
    wire signed [31:0] shifted_mac = raw_mac >>> shift_val;

    // Apply Absolute Value (Crucial for Edge Detection)
    wire signed [31:0] abs_mac = (abs_val_enable && shifted_mac < 0) ? -shifted_mac : shifted_mac;

    // Hardware Clamp (0-255)
    wire [31:0] final_pixel = (abs_mac < 0) ? 32'd0 : 
                              (abs_mac > 255) ? 32'd255 : abs_mac;

    // --------------------------------------------------------
    // 6. CPU Read Interface (1-Cycle Pipeline Sync)
    // --------------------------------------------------------
    reg [31:0] final_pixel_reg;
    
    always @(posedge clk) begin
        if (!reset) final_pixel_reg <= 32'd0;
        else final_pixel_reg <= final_pixel;
    end

    always @(*) begin
        if (raddr == 32'h00002028) rdata = final_pixel_reg; 
        else rdata = 32'h00000000;
    end

endmodule