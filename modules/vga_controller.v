`timescale 1ns / 1ps

module vga_controller (
    input  wire clk_25MHz,
    input  wire reset,

    output reg  hsync,
    output reg  vsync,
    output wire video_on,
    output reg  [9:0] x,
    output reg  [9:0] y,
    output reg  [9:0] h_count,
    output reg  [9:0] v_count
);

    localparam H_VISIBLE      = 10'd640;
    localparam H_FRONT_PORCH  = 10'd16;
    localparam H_SYNC_PULSE   = 10'd96;
    localparam H_BACK_PORCH   = 10'd48;
    localparam H_TOTAL        = 10'd800;

    localparam V_VISIBLE      = 10'd480;
    localparam V_FRONT_PORCH  = 10'd10;
    localparam V_SYNC_PULSE   = 10'd2;
    localparam V_BACK_PORCH   = 10'd33;
    localparam V_TOTAL        = 10'd525;

    wire h_active = (h_count < H_VISIBLE);
    wire v_active = (v_count < V_VISIBLE);

    assign video_on = h_active && v_active;

    always @(posedge clk_25MHz or negedge reset) begin
        if (!reset) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
            x <= 10'd0;
            y <= 10'd0;
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end else begin
                h_count <= h_count + 10'd1;
            end

            x <= h_count;
            y <= v_count;

            hsync <= ~((h_count >= (H_VISIBLE + H_FRONT_PORCH)) &&
                       (h_count <  (H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE)));

            vsync <= ~((v_count >= (V_VISIBLE + V_FRONT_PORCH)) &&
                       (v_count <  (V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE)));
        end
    end

endmodule
