`timescale 1ns / 1ps

module stream_accel #(
    parameter IMG_WIDTH = 64
)(
    input  wire clk,
    input  wire reset,
    
    // NEW: One-Hot Switches from the physical board
    input  wire [3:0] switches, 
    
    // CPU Interface
    input  wire        we,
    input  wire [31:0] waddr,
    input  wire [31:0] wdata,
    input  wire [31:0] raddr,
    output reg  [31:0] rdata
);

    // 1. The 3x3 Window Registers
    reg signed [31:0] p00, p01, p02;
    reg signed [31:0] p10, p11, p12;
    reg signed [31:0] p20, p21, p22;

    wire [7:0] row1_pixel, row0_pixel;
    wire pixel_push = we && (waddr == 32'h00002024);

    line_buffer #(.WIDTH(IMG_WIDTH)) LB1 (.clk(clk), .reset(reset), .en(pixel_push), .din(wdata[7:0]), .dout(row1_pixel));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB2 (.clk(clk), .reset(reset), .en(pixel_push), .din(row1_pixel), .dout(row0_pixel));

    always @(posedge clk) begin
        if (!reset) begin
            p00<=0; p01<=0; p02<=0; p10<=0; p11<=0; p12<=0; p20<=0; p21<=0; p22<=0;
        end else if (pixel_push) begin
            p00 <= p01; p01 <= p02; p02 <= row0_pixel;
            p10 <= p11; p11 <= p12; p12 <= row1_pixel;
            p20 <= p21; p21 <= p22; p22 <= wdata[7:0];
        end
    end

    // --------------------------------------------------------
    // 2. HARDWARE KERNEL ROM (Switch Controlled)
    // --------------------------------------------------------
    reg signed [31:0] w0, w1, w2, w3, w4, w5, w6, w7, w8;
    reg [3:0] shift_val;
    reg abs_val_enable;

    always @(*) begin
        case(switches)
            4'b0001: begin // Switch 0: BOX BLUR
                w0=1; w1=1; w2=1; w3=1; w4=1; w5=1; w6=1; w7=1; w8=1;
                shift_val = 3;  // Divide by 8
                abs_val_enable = 0;
            end
            4'b0010: begin // Switch 1: EDGE DETECT
                w0=-1; w1=-1; w2=-1; w3=-1; w4=8; w5=-1; w6=-1; w7=-1; w8=-1;
                shift_val = 0;  // No division
                abs_val_enable = 1; // Needs absolute value!
            end
            4'b0100: begin // Switch 2: SHARPEN
                w0=0; w1=-1; w2=0; w3=-1; w4=5; w5=-1; w6=0; w7=-1; w8=0;
                shift_val = 0;  
                abs_val_enable = 0; 
            end
            default: begin // All switches off: IDENTITY (Pass-through)
                w0=0; w1=0; w2=0; w3=0; w4=1; w5=0; w6=0; w7=0; w8=0;
                shift_val = 0;
                abs_val_enable = 0;
            end
        endcase
    end

    // --------------------------------------------------------
    // 3. THE FULLY AUTOMATED MATH ENGINE
    // --------------------------------------------------------
    // Raw MAC
    wire signed [31:0] raw_mac = 
        (p00 * w0) + (p01 * w1) + (p02 * w2) +
        (p10 * w3) + (p11 * w4) + (p12 * w5) +
        (p20 * w6) + (p21 * w7) + (p22 * w8);

    // Apply Shift
    wire signed [31:0] shifted_mac = raw_mac >>> shift_val;

    // Apply Absolute Value (if enabled)
    wire signed [31:0] abs_mac = (abs_val_enable && shifted_mac < 0) ? -shifted_mac : shifted_mac;

    // Apply Hardware Saturation (Clamp 0-255)
    wire [31:0] final_pixel = (abs_mac < 0) ? 32'd0 : 
                              (abs_mac > 255) ? 32'd255 : abs_mac;

    // 4. CPU Read Interface
    // --------------------------------------------------------
    // 4. CPU Read Interface (1-Cycle Registered Output)
    // --------------------------------------------------------
    reg [31:0] final_pixel_reg;

    // Latch the math result on the clock edge so it aligns with the CPU pipeline
    always @(posedge clk) begin
        if (!reset) begin
            final_pixel_reg <= 32'd0;
        end else begin
            final_pixel_reg <= final_pixel;
        end
    end

    // CPU reads the stable, registered pixel
    always @(*) begin
        if (raddr == 32'h00002028) begin
            rdata = final_pixel_reg; 
        end else begin
            rdata = 32'h00000000;
        end
    end

    // always @(*) begin
    //     if (raddr == 32'h00002028) begin
    //         rdata = final_pixel; // CPU reads the fully processed, scaled, saturated pixel!
    //     end else begin
    //         rdata = 32'h00000000;
    //     end
    // end

endmodule