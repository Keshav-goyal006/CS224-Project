`timescale 1ns/1ps

module branch_predictor (
    input  wire        clk,
    input  wire        reset,

    // --------------------------------------------------------
    // READ PORT (Used by Fetch Stage in pipeline.v)
    // --------------------------------------------------------
    input  wire [31:0] read_pc,
    output wire        predict_taken,
    output wire [31:0] predict_target,

    // --------------------------------------------------------
    // WRITE PORT (Used by Execute Stage for feedback)
    // --------------------------------------------------------
    input  wire        update_en,     // High when EX resolves a branch
    input  wire [31:0] update_pc,     // The PC of the branch instruction
    input  wire        actual_taken,  // Did the branch actually happen?
    input  wire [31:0] actual_target  // Where did it actually go?
);

    // BHT + BTB combined table
    // 64 entries. Indexed by PC[7:2]
    // 34 bits per entry: {2-bit counter, 32-bit target address}
    reg [33:0] btb [0:63];

    // Index calculation (Word aligned, so we drop bits 1:0)
    wire [5:0] read_idx   = read_pc[7:2];
    wire [5:0] update_idx = update_pc[7:2];

    // --------------------------------------------------------
    // 1. COMBINATIONAL PREDICTION (For Fetch)
    // --------------------------------------------------------
    wire [1:0] read_counter = btb[read_idx][33:32];
    
    // Predict TAKEN if counter is 10 (Weakly Yes) or 11 (Strongly Yes)
    assign predict_taken  = (read_counter >= 2'b10);
    assign predict_target = btb[read_idx][31:0];

    // --------------------------------------------------------
    // 2. SYNCHRONOUS UPDATE (Feedback from Execute)
    // --------------------------------------------------------
    integer i;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            // Initialize all entries to Strongly Not Taken (00) and Target 0
            for (i = 0; i < 64; i = i + 1) begin
                btb[i] <= 34'b0; 
            end
        end else if (update_en) begin
            // Overwrite the target address with the actual reality
            btb[update_idx][31:0] <= actual_target;

            // 2-Bit Saturating Counter State Machine
            if (actual_taken) begin
                // If taken, increment unless already at max (11)
                if (btb[update_idx][33:32] != 2'b11)
                    btb[update_idx][33:32] <= btb[update_idx][33:32] + 1'b1;
            end else begin
                // If not taken, decrement unless already at min (00)
                if (btb[update_idx][33:32] != 2'b00)
                    btb[update_idx][33:32] <= btb[update_idx][33:32] - 1'b1;
            end
        end
    end

endmodule