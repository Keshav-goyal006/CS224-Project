module instr_mem (
	input  wire    	clk,
	input  wire [31:0] pc, 	// byte address
	output reg  [31:0] instr
);

	// 1024 words = 4 KB
	// Declare instruction memory array (word-addressable, 4 KB total)
	(* ram_style = "block" *)
	reg [31:0] imem [0:1023];

	// FPGA ROM initialization
	// Initialize instruction memory from hex file (simulation / FPGA)
	initial begin
    	$readmemh("D:/New/CS224/CS224-Project/mem_generator/imem_dmem/imem.hex", imem);
	end

	// Synchronous instruction fetch
	// Use word-aligned PC (pc[11:2]) to index memory
	always @(posedge clk) begin
    	instr <= imem[pc[11:2]];	// word address
	end

endmodule



//====================================
// Data Memory (DMEM) - FPGA-safe
//====================================
// module data_mem (
// 	input     	clk,

// 	// Read port
// 	input     	re,
// 	input  [31:0] raddr,   // byte address
// 	output reg [31:0] rdata,

// 	// Write port
// 	input     	we,
// 	input  [31:0] waddr,   // byte address
// 	input  [31:0] wdata,
// 	input  [3:0]  wstrb
// );

// 	// Declare data memory array (word-addressable, 4 KB total)
// 	// TODO-DMEM-1: Declare dmem
//     (* ram_style = "block" *)
// 	// (* dont_touch = "true" *)
// 	reg [31:0] dmem [0:1023];
// 	// Decode byte address to word index
// 	wire [9:0] rindex = raddr[11:2];
// 	wire [9:0] windex = waddr[11:2];

// 	// Simulation / FPGA init
// 	// TODO-DMEM-2: Initialize data memory from dmem.hex file
//     initial begin
//         $readmemh("D:/New/CS224/CS224-Project/mem_generator/imem_dmem/dmem.hex",dmem);
//     end
// 	// -------------------------
// 	// WRITE + READ (SYNC)
// 	// -------------------------

// 	// Synchronous write and read logic
// 	// - Support byte-wise writes using wstrb
// 	// - Provide 1-cycle read latency
// 	// - Handle same-cycle read-after-write using byte-level forwarding

// 	always @(posedge clk) begin
//     	// ---- WRITE ----
//     	if (we) begin
//         	if (wstrb[0]) dmem[windex][7:0]   <= wdata[7:0];
//         	if (wstrb[1]) dmem[windex][15:8]  <= wdata[15:8];
//         	if (wstrb[2]) dmem[windex][23:16] <= wdata[23:16];// TODO-DMEM-3
//         	if (wstrb[3]) dmem[windex][31:24] <= wdata[31:24];// TODO-DMEM-3
//     	end

//     	// ---- READ (1-cycle latency, RAW-safe) ----
//     	if (re) begin
//         	if (we && (rindex == windex)) begin
//             	// Byte-level forwarding
//             	rdata[7:0]   <= wstrb[0] ? wdata[7:0]   : dmem[rindex][7:0];
//             	rdata[15:8]  <= wstrb[1] ? wdata[15:8]   : dmem[rindex][15:8];// TODO-DMEM-3
//             	rdata[23:16] <= wstrb[2] ? wdata[23:16]   : dmem[rindex][23:16];// TODO-DMEM-3
//             	rdata[31:24] <= wstrb[3] ? wdata[31:24]   : dmem[rindex][31:24];// TODO-DMEM-3
//         	end
//         	else begin
//             	rdata <= dmem[rindex];
//         	end
//     	end
//     	// else: rdata holds value (exact match to original)
// 	end
// 	// always @(posedge clk) begin
//     //     // 1. BULLETPROOF WRITE: Ignore wstrb, just write the whole 32-bit word!
//     //     if (we) begin
//     //         dmem[windex] <= wdata;
//     //     end

//     //     // 2. BULLETPROOF READ: Always return data, ignore 're'
//     //     if (we && (rindex == windex)) begin
//     //         rdata <= wdata; // RAW forwarding
//     //     end else begin
//     //         rdata <= dmem[rindex];
//     //     end
//     // end

// endmodule

module data_mem (
    input  wire        clk,

    // Read port
    input  wire        re,
    input  wire [31:0] raddr,
    output reg  [31:0] rdata,

    // Write port
    input  wire        we,
    input  wire [31:0] waddr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb
);

    // 1. PURE BRAM ARRAY
    (* ram_style = "block" *)
    reg [31:0] dmem [0:1023];

    wire [9:0] rindex = raddr[11:2];
    wire [9:0] windex = waddr[11:2];

    initial begin
        $readmemh("D:/New/CS224/CS224-Project/mem_generator/imem_dmem/dmem.hex", dmem);
    end

    // 2. INTERNAL REGISTERS (For 1-Cycle Delay)
    reg [31:0] bram_rdata;      
    reg [31:0] fwd_data;        // Holds the data to bypass
    reg [3:0]  fwd_strb;        // Holds the byte enables to bypass
    reg        fwd_en;          // Flag to trigger the bypass mux

    // 3. SYNCHRONOUS BLOCK (BRAM Inference + Hazard Detection)
    always @(posedge clk) begin
        
        // --- BRAM WRITE ---
        if (we) begin
            if (wstrb[0]) dmem[windex][7:0]   <= wdata[7:0];
            if (wstrb[1]) dmem[windex][15:8]  <= wdata[15:8];
            if (wstrb[2]) dmem[windex][23:16] <= wdata[23:16];
            if (wstrb[3]) dmem[windex][31:24] <= wdata[31:24];
        end

        // --- BRAM READ & HAZARD DETECTION ---
        if (re) begin
            // Normal BRAM read (takes 1 cycle to appear on bram_rdata)
            bram_rdata <= dmem[rindex];

            // If CPU is writing to the exact same address it is reading THIS cycle...
            if (we && (windex == rindex)) begin
                fwd_en   <= 1'b1;     // Set the bypass flag for the next cycle
                fwd_data <= wdata;    // Save the new data
                fwd_strb <= wstrb;    // Save the byte enables
            end else begin
                fwd_en   <= 1'b0;     // No hazard, use normal BRAM data
            end
        end
    end

    // 4. COMBINATORIAL OUTPUT MUX
    // This executes on the very next cycle when the CPU actually looks at 'rdata'
    always @(*) begin
        // Default: output the data that the BRAM just fetched
        rdata = bram_rdata; 

        // Override with forwarded data if a hazard was flagged last cycle!
        if (fwd_en) begin
            if (fwd_strb[0]) rdata[7:0]   = fwd_data[7:0];
            if (fwd_strb[1]) rdata[15:8]  = fwd_data[15:8];
            if (fwd_strb[2]) rdata[23:16] = fwd_data[23:16];
            if (fwd_strb[3]) rdata[31:24] = fwd_data[31:24];
        end
    end

endmodule