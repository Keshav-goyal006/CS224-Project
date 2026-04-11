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

    reg signed [31:0] weights [0:8];
    reg signed [31:0] pixels  [0:8];
    
    wire [5:0] w_idx = waddr[7:2];
    wire [5:0] r_idx = raddr[7:2];
    
    integer i;

    // Write Logic
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            for (i = 0; i < 9; i = i + 1) begin
                weights[i] <= 32'd0;
                pixels[i]  <= 32'd0;
            end
        end 
        else if (we) begin
            if (w_idx >= 0 && w_idx <= 8) begin
                weights[w_idx] <= wdata;
            end
            else if (w_idx >= 16 && w_idx <= 24) begin
                pixels[w_idx - 16] <= wdata;
            end
        end
    end

    // Combinational 3x3 MAC
    wire signed [31:0] mac_result = 
        (pixels[0] * weights[0]) + (pixels[1] * weights[1]) + (pixels[2] * weights[2]) +
        (pixels[3] * weights[3]) + (pixels[4] * weights[4]) + (pixels[5] * weights[5]) +
        (pixels[6] * weights[6]) + (pixels[7] * weights[7]) + (pixels[8] * weights[8]);

    // Read Logic
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            rdata <= 32'b0;
        end else begin
            // 0x00002080 is the RESULT address. 
            // Depending on how you wired raddr, check the lower bits!
            // (If raddr is the raw byte address, check for 8'h80)
            if (raddr[7:0] == 8'h80) begin 
                // Latch the math result onto the bus securely!
                rdata <= mac_result;
            end else begin
                // Default to 0 to prevent bus latching
                rdata <= 32'b0; 
            end
        end
    end
    // always @(*) begin
    //     // Read Result from 0x2080 (Index 32)
    //     if (r_idx == 32) begin
    //         rdata = mac_result;
    //     end else begin
    //         rdata = 32'd0;
    //     end
    // end

endmodule