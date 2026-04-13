`timescale 1ns/1ps

module mac_accelerator (
    input clk,
    input reset,

    // Memory Interface
    input         we,
    input  [31:0] waddr,
    input  [31:0] wdata,

    input  [31:0] raddr,
    output reg [31:0] rdata    // Data back to CPU
);

    // Legacy scalar MAC registers (compatible with 0x2000/0x2004/0x2008/0x200C)
    reg signed [31:0] reg_a;
    reg signed [31:0] accumulator;

    // 5x5 vector MAC storage
    reg signed [31:0] weights [0:24];
    reg signed [31:0] pixels  [0:24];

    // We decode by word offsets within the 0x2000 MMIO page.
    wire [5:0] w_idx = waddr[7:2];
    wire [5:0] r_idx = raddr[7:2];

    integer i;
    integer j;
    reg signed [63:0] dot_sum;

    localparam [5:0] LEGACY_A_IDX      = 6'd0;   // 0x2000
    localparam [5:0] LEGACY_B_IDX      = 6'd1;   // 0x2004
    localparam [5:0] LEGACY_RESULT_IDX = 6'd2;   // 0x2008
    localparam [5:0] LEGACY_CLEAR_IDX  = 6'd3;   // 0x200C

    localparam [5:0] VEC_W_BASE_IDX    = 6'd4;   // 0x2010 .. 0x2070
    localparam [5:0] VEC_W_LAST_IDX    = 6'd28;
    localparam [5:0] VEC_P_BASE_IDX    = 6'd32;  // 0x2080 .. 0x20E0
    localparam [5:0] VEC_P_LAST_IDX    = 6'd56;
    localparam [5:0] VEC_RESULT_IDX    = 6'd60;  // 0x20F0
    localparam [5:0] VEC_CLEAR_IDX     = 6'd61;  // 0x20F4

    // Combinational 5x5 dot product.
    always @(*) begin
        dot_sum = 64'sd0;
        for (j = 0; j < 25; j = j + 1) begin
            dot_sum = dot_sum + ($signed(weights[j]) * $signed(pixels[j]));
        end
    end

    // Write logic
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            reg_a       <= 32'd0;
            accumulator <= 32'd0;
            for (i = 0; i < 25; i = i + 1) begin
                weights[i] <= 32'd0;
                pixels[i]  <= 32'd0;
            end
        end
        else if (we) begin
            if (w_idx >= VEC_W_BASE_IDX && w_idx <= VEC_W_LAST_IDX) begin
                weights[w_idx - VEC_W_BASE_IDX] <= wdata;
            end else if (w_idx >= VEC_P_BASE_IDX && w_idx <= VEC_P_LAST_IDX) begin
                pixels[w_idx - VEC_P_BASE_IDX] <= wdata;
            end else begin
                case (w_idx)
                    LEGACY_A_IDX: reg_a <= wdata;
                    LEGACY_B_IDX: accumulator <= accumulator + (reg_a * wdata);
                    LEGACY_CLEAR_IDX: accumulator <= 32'd0;
                    VEC_CLEAR_IDX: begin
                        for (i = 0; i < 25; i = i + 1) begin
                            weights[i] <= 32'd0;
                            pixels[i]  <= 32'd0;
                        end
                    end
                    default: begin
                        // no-op
                    end
                endcase
            end
        end
    end

    // Read logic
    always @(*) begin
        if (r_idx >= VEC_W_BASE_IDX && r_idx <= VEC_W_LAST_IDX) begin
            rdata = weights[r_idx - VEC_W_BASE_IDX];
        end else if (r_idx >= VEC_P_BASE_IDX && r_idx <= VEC_P_LAST_IDX) begin
            rdata = pixels[r_idx - VEC_P_BASE_IDX];
        end else begin
            case (r_idx)
                LEGACY_A_IDX:      rdata = reg_a;
                LEGACY_RESULT_IDX: rdata = accumulator;
                VEC_RESULT_IDX:    rdata = dot_sum[31:0];
                default:           rdata = 32'd0;
            endcase
        end
    end
    

endmodule