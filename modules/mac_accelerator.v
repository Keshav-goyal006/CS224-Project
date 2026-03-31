`timescale 1ns/1ps

module mac_accelerator (
    input clk,
    input reset,
    
    // Memory Interface
    input         we,          // Write Enable
    input  [31:0] wdata,       // Data from CPU
    input  [1:0]  addr_offset, // Last 2 bits of the address to select registers
    
    output reg [31:0] rdata    // Data back to CPU
);

    // Internal Registers
    reg signed [31:0] reg_a;
    reg signed [31:0] accumulator;

    // --- Write Logic (The MAC Operation) ---
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            reg_a       <= 32'd0;
            accumulator <= 32'd0;
        end 
        else if (we) begin
            case (addr_offset)
                2'b00: reg_a <= wdata;                      // Write to Address 0x2000: Load A
                2'b01: accumulator <= accumulator + (reg_a * wdata); // Write to 0x2004: Load B and MAC!
                2'b11: accumulator <= 32'd0;                // Write to 0x200C: Clear the accumulator
            endcase
        end
    end

    // --- Read Logic ---
    always @(*) begin
        if (addr_offset == 2'b10) begin
            rdata = accumulator; // Read from 0x2008: Get the Result
        end else begin
            rdata = 32'd0;
        end
    end

endmodule