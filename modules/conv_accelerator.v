`timescale 1ns/1ps

module conv_accelerator (
    input clk,
    input reset,
    
    input         we,          
    input  [31:0] waddr,
    input  [31:0] wdata,
    
    input  [31:0] raddr,
    output reg [31:0] rdata
);

    reg signed [31:0] weights [0:24];
    reg signed [31:0] pixels  [0:24];
    
    wire [5:0] w_idx = waddr[7:2];
    wire [5:0] r_idx = raddr[7:2];
    
    integer i;
    integer j;
    reg signed [63:0] mac_sum;

    localparam [5:0] W_BASE_IDX  = 6'd0;   // 0x2000 .. 0x2060
    localparam [5:0] W_LAST_IDX  = 6'd24;
    localparam [5:0] P_BASE_IDX  = 6'd32;  // 0x2080 .. 0x20E0
    localparam [5:0] P_LAST_IDX  = 6'd56;
    localparam [5:0] RES_IDX     = 6'd60;  // 0x20F0
    localparam [5:0] CLEAR_IDX   = 6'd61;  // 0x20F4

    // Write Logic
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            for (i = 0; i < 25; i = i + 1) begin
                weights[i] <= 32'd0;
                pixels[i]  <= 32'd0;
            end
        end
        else if (we) begin
            if (w_idx >= W_BASE_IDX && w_idx <= W_LAST_IDX) begin
                weights[w_idx - W_BASE_IDX] <= wdata;
            end else if (w_idx >= P_BASE_IDX && w_idx <= P_LAST_IDX) begin
                pixels[w_idx - P_BASE_IDX] <= wdata;
            end else if (w_idx == CLEAR_IDX) begin
                for (i = 0; i < 25; i = i + 1) begin
                    weights[i] <= 32'd0;
                    pixels[i]  <= 32'd0;
                end
            end
        end
    end

    // Combinational 5x5 MAC
    always @(*) begin
        mac_sum = 64'sd0;
        for (j = 0; j < 25; j = j + 1) begin
            mac_sum = mac_sum + ($signed(weights[j]) * $signed(pixels[j]));
        end
    end

    // Read Logic
    always @(*) begin
        if (r_idx >= W_BASE_IDX && r_idx <= W_LAST_IDX) begin
            rdata = weights[r_idx - W_BASE_IDX];
        end else if (r_idx >= P_BASE_IDX && r_idx <= P_LAST_IDX) begin
            rdata = pixels[r_idx - P_BASE_IDX];
        end else if (r_idx == RES_IDX) begin
            rdata = mac_sum[31:0];
        end else begin
            rdata = 32'd0;
        end
    end

endmodule