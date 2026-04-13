`timescale 1ns / 1ps

module vga_controller (
    input wire clk_25MHz,   // MUST be exactly 25 MHz
    input wire reset,
    
    output reg hsync,       // To VGA cable
    output reg vsync,       // To VGA cable
    output reg video_on,    // High when we are in the visible screen area
    output wire [9:0] x,    // Current X coordinate (0 to 639)
    output wire [9:0] y     // Current Y coordinate (0 to 479)
);

    // Standard VGA 640x480 @ 60Hz Parameters
    parameter HD = 640;             // Horizontal Display Area
    parameter HF = 16;              // Horizontal Front Porch
    parameter HB = 48;              // Horizontal Back Porch
    parameter HR = 96;              // Horizontal Retrace (Sync)
    parameter HMAX = HD+HF+HB+HR-1; // 799

    parameter VD = 480;             // Vertical Display Area
    parameter VF = 10;              // Vertical Front Porch
    parameter VB = 33;              // Vertical Back Porch
    parameter VR = 2;               // Vertical Retrace (Sync)
    parameter VMAX = VD+VF+VB+VR-1; // 524

    reg [9:0] h_count;
    reg [9:0] v_count;

    // Counters
    always @(posedge clk_25MHz or negedge reset) begin
        if (!reset) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count == HMAX) begin
                h_count <= 0;
                if (v_count == VMAX)
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

   
    always @(posedge clk_25MHz or negedge reset) begin
        if (!reset) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else begin
            hsync <= ~(h_count >= (HD + HF) && h_count < (HD + HF + HR));
            vsync <= ~(v_count >= (VD + VF) && v_count < (VD + VF + VR));
        end
    end

    // Video On Signal (Only draw when we are inside the 640x480 zone)
    always @(posedge clk_25MHz or negedge reset) begin
        if (!reset)
            video_on <= 1'b0;
        else
            video_on <= (h_count < HD) && (v_count < VD);
    end

    // Output current coordinates
    assign x = h_count;
    assign y = v_count;

endmodule