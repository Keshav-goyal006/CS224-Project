`timescale 1ns / 1ps

module tb_pipeline;

////////////////////////////////////////////////////////////
// CLOCK & RESET
////////////////////////////////////////////////////////////
reg clk;
reg reset;

// 100 MHz clock
initial begin
	clk = 0;
	forever #5 clk = ~clk;
end

// reset (active low in our CPU)
initial begin
	reset = 0;
	#100;
	reset = 1;
end

initial begin
    // Specify the name of the output VCD file
    $dumpfile("pipeline.vcd");
    
    // Dump all variables in the testbench and its instantiated modules
    // '0' means all levels of hierarchy. 
    // Replace 'tb_file' with the actual name of your testbench module if it's different.
    $dumpvars(0, tb_pipeline); 
end
////////////////////////////////////////////////////////////
// PIPE ↔ MEMORY SIGNALS
////////////////////////////////////////////////////////////
wire [31:0] inst_mem_read_data;
wire    	inst_mem_is_valid;

wire [31:0] dmem_read_data;
wire    	dmem_write_valid;
wire    	dmem_read_valid;

assign inst_mem_is_valid = 1'b1;
assign dmem_write_valid  = 1'b1;
assign dmem_read_valid   = 1'b1;

////////////////////////////////////////////////////////////
// PIPE ↔ MEMORY WIRES
////////////////////////////////////////////////////////////
wire [31:0] inst_mem_address;
wire        dmem_read_ready;
wire [31:0] dmem_read_address;
wire        dmem_write_ready;
wire [31:0] dmem_write_address;
wire [31:0] dmem_write_data;
wire [3:0]  dmem_write_byte;

wire exception;


////////////////////////////////////////////////////////////
// DUT : PIPELINE CPU
////////////////////////////////////////////////////////////
pipe DUT (
	.clk(clk),
	.reset(reset),
	.stall(1'b0),
	.exception(exception),
    .pc_out(),
    
	.inst_mem_is_valid(inst_mem_is_valid),
	.inst_mem_read_data(inst_mem_read_data),

	.dmem_read_data_temp(dmem_read_data),
	.dmem_write_valid(dmem_write_valid),
	.dmem_read_valid(dmem_read_valid),
// TODO: Might have a few more port signals
    .inst_mem_address(inst_mem_address),
    .dmem_read_ready(dmem_read_ready),
    .dmem_read_address(dmem_read_address),
    .dmem_write_ready(dmem_write_ready),
    .dmem_write_address(dmem_write_address),
    .dmem_write_data(dmem_write_data),
    .dmem_write_byte(dmem_write_byte)
);


////////////////////////////////////////////////////////////
// INSTRUCTION MEMORY  (matches instr_mem.v)
////////////////////////////////////////////////////////////
instr_mem IMEM (
	.clk(clk),
	.pc(inst_mem_address),
//	.pc(TODO: Add inst_mem_address as a port signal from the pipe),
	.instr(inst_mem_read_data)
);


////////////////////////////////////////////////////////////
// DATA MEMORY  (matches data_mem.v)
////////////////////////////////////////////////////////////
data_mem DMEM (
	.clk(clk),
    .re(dmem_read_ready),
    .raddr(dmem_read_address),
//	.re(TODO: Add dmem_read_ready as a port signal from the pipe),
//	.raddr(TODO),
	.rdata(dmem_read_data),
    .we(dmem_write_ready),
    .waddr(dmem_write_address),
    .wdata(dmem_write_data),
    .wstrb(dmem_write_byte)
//	.we(TODO: Add dmem_write_ready as a port signal from the pipe),
//	.waddr(TODO),
//	.wdata(TODO),
//	.wstrb(TODO: Add dmem_write_byte as a port signal from the pipe)
);


////////////////////////////////////////////////////////////
// SIMULATION TIME
////////////////////////////////////////////////////////////
initial begin
	#20000;   // run long enough to see program execute
	$finish;
end

////////////////////////////////////////////////////////////
// PRINT PIPELINE OUTPUT & STOP CONDITION
////////////////////////////////////////////////////////////
reg program_started = 0;

always @(posedge clk) begin
    // Only run if the processor is active (reset is off)
    if (reset == 1) begin
        
        // 1. Spy on Data Memory Writes to print the results
        if (dmem_write_ready) begin
            $display("time:\t\t%0d ,result =\t\t%0d", $time, dmem_write_data);
        end
        
        // 2. Stop the simulation if it loops back to the beginning
        if (program_started == 1 && inst_mem_address == 32'h00000000) begin
            $display("All instructions are Fetched");
            $display("next_pc = %08x", inst_mem_address);
            $finish;
        end
        
        // 3. Track that the program has safely started
        if (inst_mem_address > 0) begin
            program_started = 1;
        end
        
        // 4. Print the PC every cycle
        $display("next_pc = %08x", inst_mem_address);
    end
end

endmodule