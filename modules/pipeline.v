//////////////// Including Stages ////////////////////////////
`include "IF_ID.v"
`include "execute.v"
`include "wb.v"
`include "mac_accelerator.v"

 module pipe
#(
	parameter [31:0]         	RESET = 32'h0000_0000
)
(
	input               	clk,
	input               	reset,
	input               	stall,
	output          	exception,  
	output [31:0] pc_out,

	// interface of instruction Memory
	input               	inst_mem_is_valid,
	input       	[31: 0] inst_mem_read_data,
	input       	[31: 0] dmem_read_data_temp,
	input               	dmem_write_valid,
	input               	dmem_read_valid,
    input        	[15:0] switch_in,
	
	output       [31: 0]  inst_mem_address,
    output                dmem_read_ready,
    output       [31: 0]  dmem_read_address,
    output                dmem_write_ready,
    output       [31: 0]  dmem_write_address,
    output       [31: 0]  dmem_write_data,
    output       [ 3: 0]  dmem_write_byte,

    output       [15:0]   led_out
);
    
	//Declaring Wires and Registers

	//Data Memory Wires
    
	wire      	[31: 0] dmem_read_data;
//	wire              	dmem_write_ready;
//	wire              	dmem_read_ready;
//	wire      	[31: 0] dmem_write_address;
//	wire      	[31: 0] dmem_read_address;
	wire        	[1:0]  dmem_read_offset;
//	wire      	[31: 0] dmem_write_data;
//	wire      	[ 3: 0] dmem_write_byte;
	wire              	inst_mem_is_ready;
	wire              	dmem_read_valid_checker;
    
	//Instruction Fetch/Decode Stage
    
	reg       	[31: 0] immediate;
	wire               	immediate_sel;
	wire       	[ 4: 0] src1_select;
	wire       	[ 4: 0] src2_select;
	wire       	[ 4: 0] dest_reg_sel;
	wire       	[ 2: 0] alu_operation;
	wire               	arithsubtype;
    wire                is_m_ext;
	wire               	mem_write;
	wire               	mem_to_reg;
	wire               	illegal_inst;
	wire       	[31: 0] execute_immediate;
	wire               	alu;
	wire               	lui;
	wire               	jal;
	wire               	jalr;
	wire               	branch;
	reg               	stall_read;
	wire      	[31: 0] instruction;
	wire      	[31: 0] reg_rdata2 ;
	wire      	[31: 0] reg_rdata1;
	reg       	[31: 0] regs [31: 1];

	// PC

	wire        	[31: 0] pc;
	wire        	[31: 0] inst_fetch_pc;
	reg        	[31: 0] fetch_pc ;  

	//Stalls
    
	wire 	wb_stall_first;
	wire 	wb_stall_second;
	wire	wb_stall;

    localparam [31:0] MMIO_CONV_BASE  = 32'h00002000;
    localparam [31:0] MMIO_CONV_LIMIT = 32'h00002100;
    localparam [31:0] MMIO_SWITCH_ADDR = 32'h00003100;
    localparam [31:0] MMIO_LED_ADDR   = 32'h00003000;
    localparam [31:0] MMIO_TRAP_ADDR  = 32'h00004000;
        	 
       	 
	//Execute Stage

    
	wire         	[31: 0] next_pc;
	wire        	[31: 0] write_address;
	wire                 	branch_taken;
	wire                	branch_stall;
	wire        	[31:0] alu_operand1;
	wire        	[31:0] alu_operand2;

	// Write Back
    
	wire                	wb_alu_to_reg;
	wire        	[31: 0] wb_result;
	wire        	[ 2: 0] wb_alu_operation;
	wire                	wb_mem_write;
	wire                	wb_mem_to_reg;
	wire        	[ 4: 0] wb_dest_reg_sel;
	wire                	wb_branch;
	wire                	wb_branch_nxt;
	wire        	[31: 0] wb_write_address;
	wire        	[ 1: 0] wb_read_address;
	wire        	[ 3: 0] wb_write_byte;
	wire        	[31: 0] wb_write_data;
	wire        	[31: 0] wb_read_data;
//	wire       	[31: 0] inst_mem_address;

//------------------------------------------------------//
assign dmem_write_address       	= wb_write_address; 	// assigning where to write
assign dmem_read_address        	= alu_operand1 + execute_immediate;  // Assigning address to read from the data memory
assign dmem_read_offset = dmem_read_address[1:0];
assign dmem_read_ready          	= mem_to_reg;   // load instruction flag to read from memory
assign dmem_write_ready         	= wb_mem_write; 	// flag to write into the memory
assign dmem_write_data          	= wb_write_data;	// assigning data to write
assign dmem_write_byte          	= wb_write_byte;	// flag for writing the data bytes
assign dmem_read_data           	= dmem_read_data_temp;  	// data read from the memory
assign dmem_read_valid_checker  	= 1'b1;
// -----------------------------------------------------//

// instantiating Instruction fetch module -----------------------
IF_ID IF_ID_stage (
	.clk            	(clk),
	.reset          	(reset),
	.stall          	(stall),
	.exception      	(exception),

	// Instruction memory interface
	.inst_mem_is_valid  (inst_mem_is_valid),
	.inst_mem_read_data (inst_mem_read_data),

	// Previously pipe.* signals (now explicit ports)
	.stall_read_i   	(stall_read),
	.inst_fetch_pc  	(inst_fetch_pc),
	.instruction_i  	(instruction),

	// WB-stage signals
	.wb_stall       	(wb_stall),
	.wb_alu_to_reg  	(wb_alu_to_reg),
	.wb_mem_to_reg  	(wb_mem_to_reg),
	.wb_dest_reg_sel	(wb_dest_reg_sel),
	.wb_result      	(wb_result),
	.wb_read_data   	(wb_read_data),

	// Instruction memory address offset
	.inst_mem_offset	(inst_mem_address[1:0]),

	// Output wires (write-only)
	.execute_immediate_w (execute_immediate),
	.immediate_sel_w	(immediate_sel),
	.alu_w          	(alu),
	.lui_w          	(lui),
	.jal_w          	(jal),
	.jalr_w         	(jalr),
	.branch_w       	(branch),
	.mem_write_w    	(mem_write),
	.mem_to_reg_w   	(mem_to_reg),
	.arithsubtype_w 	(arithsubtype),
    .m_ext_w            (is_m_ext),
	.pc_w           	(pc),
	.src1_select_w  	(src1_select),
	.src2_select_w  	(src2_select),
	.dest_reg_sel_w 	(dest_reg_sel),
	.alu_operation_w	(alu_operation),
	.illegal_inst_w 	(illegal_inst),
	.instruction_o  	(instruction)
);


    ////////////////////////////////////////////////////////////
    // TODO: Register File Forwarding
    //
    // - If src register is x0 (5'd0) → return 0
    // - If WB stage writes same register (and not stalled) → forward:
    //    	wb_read_data (for LOAD)
    //    	wb_result	(for ALU)
    // - Else → read from register array (regs)
    ////////////////////////////////////////////////////////////
    
    assign reg_rdata1 =
        (src1_select == 5'd0) ? 32'b0:
        (!wb_stall && wb_alu_to_reg &&
        (wb_dest_reg_sel == src1_select))
            ? (wb_mem_to_reg ? wb_read_data : wb_result)
            : regs[src1_select];
    
    assign reg_rdata2 = 
        (src2_select == 5'd0) ? 32'd0 :
        (!wb_stall && wb_alu_to_reg && 
        (wb_dest_reg_sel == src2_select)) 
            ? (wb_mem_to_reg ? wb_read_data : wb_result) 
            : regs[src2_select];
    
    ////////////////////////////////////////////////////////////
    // TODO: Register File Writeback
    //
    // On reset:
    //   - Clear registers x1–x31
    //
    // On valid WB cycle:
    //   - If wb_alu_to_reg asserted
    //   - AND no stall
    //   - Write either:
    //    	wb_read_data (LOAD)
    //    	wb_result	(ALU result)
    ////////////////////////////////////////////////////////////

    integer i;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            for (i = 1; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end
        else if (wb_alu_to_reg && !stall_read && !wb_stall) begin
            if (wb_dest_reg_sel != 5'd0) begin
                regs[wb_dest_reg_sel] <=
                    wb_mem_to_reg ? wb_read_data : wb_result;
            end
//            regs[wb_dest_reg_sel] <=
//                wb_mem_to_reg ? wb_read_data : wb_result;
        end
    end


    ////////////////////////////////////////////////////////////
    // Stall register
    ////////////////////////////////////////////////////////////
    
    always @(posedge clk or negedge reset) begin
        if (!reset)
            stall_read <= 1'b1;
        else
            stall_read <= stall;
    end

// instantiating execute module -----------------------------------
    execute execute (
        // -----------------
        // Clock / Reset
        // -----------------
        .clk          	(clk),
        .reset        	(reset),
    
        // -----------------
        // FROM ID/EX
        // -----------------
        // ---- TODO: Connect ID/EX signals ----
        // .reg_rdata1   ( ... ),
        // Add remaining ID/EX connections here
    
        .reg_rdata1       (reg_rdata1),
        .reg_rdata2       (reg_rdata2),
        .execute_imm      (execute_immediate),
        .pc               (pc),
        .fetch_pc         (fetch_pc),
        .immediate_sel    (immediate_sel),
        .mem_write        (mem_write),
        .jal              (jal),
        .jalr             (jalr),
        .lui              (lui),
        .alu              (alu),
        .branch           (branch),
        .arithsubtype     (arithsubtype),
        .is_m_ext         (is_m_ext),
        .mem_to_reg       (mem_to_reg),
        .stall_read       (stall_read),
        .dest_reg_sel     (dest_reg_sel),
        .alu_op           (alu_operation),
        .dmem_raddr       (dmem_read_offset),
        // -----------------
        // FROM WB
        // -----------------
        .wb_branch_i  	(wb_branch),
        .wb_branch_nxt_i  (wb_branch_nxt),
    
        // -----------------
        // EX → PIPE
        // -----------------
        .alu_operand1 	(alu_operand1),
        .alu_operand2 	(alu_operand2),
        .write_address	(write_address),
        .branch_stall 	(branch_stall),
        .next_pc      	(next_pc),
        .branch_taken 	(branch_taken),
    
        // -----------------
        // EX → WB
        // -----------------
        // ---- TODO: Connect EX → WB signals ----
        .wb_result      (wb_result),
        .wb_mem_write   (wb_mem_write),
        .wb_alu_to_reg  (wb_alu_to_reg),
        .wb_dest_reg_sel(wb_dest_reg_sel),
        .wb_branch      (wb_branch),
        .wb_branch_nxt  (wb_branch_nxt),
        .wb_mem_to_reg  (wb_mem_to_reg),
        .wb_read_address(wb_read_address),
        .mem_alu_operation(wb_alu_operation)
        // .wb_result (wb_result)
        // .wb_mem_write
        // .wb_alu_to_reg
        // .wb_dest_reg_sel
        // .wb_branch
        // .wb_branch_nxt
        // .wb_mem_to_reg
        // .wb_read_address
        // .mem_alu_operation
    );



////////////////////////////////////////////////////////////
// PC Update Logic
//
// On reset:
// - Set PC = RESET
//
// On each clock (if not stalled):
// - If branch_stall = 1 → hold branch redirect and
// move sequentially (PC = PC + 4).
// - Else → update PC with next_pc
// (this could be normal next or a jump/branch address).
//
// stall_read prevents any PC update.
////////////////////////////////////////////////////////////

always @(posedge clk or negedge reset) begin
	if (!reset)
    	fetch_pc <= RESET;
	else if (!stall_read)
    	fetch_pc <= branch_stall
                     	? fetch_pc + 4
                     	: next_pc;
end


wire [31:0] coproc_read_data;
wire is_coproc_waddr = (dmem_write_address >= MMIO_CONV_BASE) && (dmem_write_address < MMIO_CONV_LIMIT);
wire is_coproc_raddr = (dmem_read_address == 32'h00002008) ||
                       (dmem_read_address == 32'h000020F0);

mac_accelerator my_mac (
    .clk(clk),
    .reset(reset),
    .we(dmem_write_ready && is_coproc_waddr),
    .waddr(dmem_write_address),
    .wdata(dmem_write_data),
    .raddr(dmem_read_address),
    .rdata(coproc_read_data)
);

// --- PIPELINE ALIGNMENT FIX ---
// DMEM has a 1-cycle read latency. The coprocessor read is instant (0-cycle).
// We must register the coprocessor output to delay it by 1 cycle so it 
// arrives at the WB stage at the exact same time as DMEM data.
reg [31:0] coproc_read_data_reg;
reg        is_coproc_raddr_reg;

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        coproc_read_data_reg <= 32'd0;
        is_coproc_raddr_reg  <= 1'b0;
    end else begin
        coproc_read_data_reg <= coproc_read_data;
        is_coproc_raddr_reg  <= is_coproc_raddr;
    end
end

// Multiplex the delayed data back to the CPU
wire [31:0] final_read_data = is_coproc_raddr_reg ? coproc_read_data_reg :
                              (dmem_read_address == MMIO_SWITCH_ADDR ? {16'h0000, switch_in} : dmem_read_data_temp);

// -------------------------------------------------------------------------
// LED Memory Mapped Register (Mapped to 0x3000)
// -------------------------------------------------------------------------
reg [15:0] led_reg;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        led_reg <= 16'b0;
    end else if (dmem_write_ready && dmem_write_address == MMIO_LED_ADDR) begin
        led_reg <= dmem_write_data[15:0];
    end
end
assign led_out = led_reg;


// instantiating Writeback module ----------------------------------
wb wb_stage (
   .clk(clk),
   .reset(reset),
    .stall_read_i        (stall_read),
    .fetch_pc_i          (fetch_pc),
    .wb_branch_i         (wb_branch),
    .wb_mem_to_reg_i     (wb_mem_to_reg),
    .mem_write_i         (mem_write),
    .write_address_i     (write_address),
    .alu_operand2_i      (alu_operand2),
    .alu_operation_i     (alu_operation),
    .wb_alu_operation_i  (wb_alu_operation),
    .wb_read_address_i   (wb_read_address),
    .dmem_read_data_i    (final_read_data),
    .dmem_write_valid_i  (dmem_write_valid),
    
    // -----------------
    // WB outputs
    // -----------------
    .inst_mem_address_o  (inst_mem_address),
    .inst_mem_is_ready_o (inst_mem_is_ready),
    .wb_stall_o          (wb_stall),
    .wb_write_address_o  (wb_write_address),
    .wb_write_data_o     (wb_write_data),
    .wb_write_byte_o     (wb_write_byte),
    .wb_read_data_o      (wb_read_data),
    .inst_fetch_pc_o     (inst_fetch_pc),
    .wb_stall_first_o    (wb_stall_first),
    .wb_stall_second_o   (wb_stall_second)
   // -----------------
   // TODO: Connect WB inputs
   // -----------------
   // .stall_read_i
   // .fetch_pc_i
   // .wb_branch_i
   // .wb_mem_to_reg_i
   // .mem_write_i
   // .write_address_i
   // .alu_operand2_i
   // .alu_operation_i
   // .wb_alu_operation_i
   // .wb_read_address_i
   // .dmem_read_data_i
   // .dmem_write_valid_i

   // -----------------
   // TODO: Connect WB outputs
   // -----------------
   // .inst_mem_address_o
   // .inst_mem_is_ready_o
   // .wb_stall_o
   // .wb_write_address_o
   // .wb_write_data_o
   // .wb_write_byte_o
   // .wb_read_data_o
   // .inst_fetch_pc_o
   // .wb_stall_first_o
   // .wb_stall_second_o
);

assign pc_out = fetch_pc;

// -------------------------------------------------------------------------
// Simulation File Output (Traps writes to 0x4000)
// -------------------------------------------------------------------------
integer file_out;

// Create the file when simulation starts
initial begin
    file_out = $fopen("output_pixels.txt", "w");
end

// Listen for the CPU writing to our magic address
always @(posedge clk) begin
    if (dmem_write_ready && dmem_write_address == MMIO_TRAP_ADDR) begin
        // Write the pixel value to the text file
        $fdisplay(file_out, "%d", $signed(dmem_write_data));
    end
end

endmodule