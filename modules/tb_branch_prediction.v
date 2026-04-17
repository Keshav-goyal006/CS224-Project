`timescale 1ns/1ps

module tb_branch_prediction;

    // ---------------------------------------------------------
    // 1. SIGNALS & WIRES
    // ---------------------------------------------------------
    reg         clk;
    reg         reset;
    reg         stall;
    reg  [15:0] switch_in;
    
    wire        exception;
    wire [31:0] pc_out;

    // Instruction Memory Wires
    wire [31:0] inst_mem_address;
    wire [31:0] inst_mem_read_data;
    
    // Data Memory Wires
    wire [31:0] dmem_read_address;
    wire [31:0] dmem_read_data_temp;
    wire [31:0] dmem_write_address;
    wire [31:0] dmem_write_data;
    wire [3:0]  dmem_write_byte;
    wire        dmem_read_ready;
    wire        dmem_write_ready;

    // ---------------------------------------------------------
    // 2. CLOCK GENERATION (100 MHz)
    // ---------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // 3. MODULE INSTANTIATIONS
    // ---------------------------------------------------------

    // Instantiate the Top-Level Pipeline
    pipe dut (
        .clk                  (clk),
        .reset                (reset),
        .stall                (stall),
        .switch_in            (switch_in),
        
        .exception            (exception),
        .pc_out               (pc_out),
        
        // Instruction Memory Interface
        .inst_mem_is_valid    (1'b1), // Always valid for basic memory
        .inst_mem_read_data   (inst_mem_read_data),
        .inst_mem_address     (inst_mem_address),
        
        // Data Memory Interface
        .dmem_read_valid      (1'b1), // Always valid for basic memory
        .dmem_write_valid     (1'b1), // Always valid for basic memory
        .dmem_read_data_temp  (dmem_read_data_temp),
        .dmem_read_ready      (dmem_read_ready),
        .dmem_read_address    (dmem_read_address),
        .dmem_write_ready     (dmem_write_ready),
        .dmem_write_address   (dmem_write_address),
        .dmem_write_data      (dmem_write_data),
        .dmem_write_byte      (dmem_write_byte)
    );

    // Instantiate the Instruction Memory
    instr_mem imem_inst (
        .clk    (clk),
        .pc     (inst_mem_address),
        .instr  (inst_mem_read_data)
    );

    // Instantiate the Data Memory
    data_mem dmem_inst (
        .clk    (clk),
        .re     (dmem_read_ready),
        .raddr  (dmem_read_address),
        .rdata  (dmem_read_data_temp),
        .we     (dmem_write_ready),
        .waddr  (dmem_write_address),
        .wdata  (dmem_write_data),
        .wstrb  (dmem_write_byte)
    );

    // ---------------------------------------------------------
    // 4. SIMULATION SEQUENCE
    // ---------------------------------------------------------
    initial begin
        // Setup Waveform Dumping
        $dumpfile("pipeline_waves.vcd");
        $dumpvars(0, tb_branch_prediction);

        // Initialize Inputs
        stall     = 0;
        switch_in = 16'h0000;
        
        // Assert Reset (Active Low based on your code)
        reset = 0;
        #20; 
        
        // Release Reset
        reset = 1;

        // Run the simulation for enough time to let the C-code loop finish.
        // The loop runs 10 times, each iteration taking a few cycles.
        // 2000ns is 200 clock cycles, which is plenty of time.
        #2000;

        // End simulation safely
        $display("Simulation Finished.");
        $finish;
    end

    // ---------------------------------------------------------
    // 5. MONITORING (Optional but helpful)
    // ---------------------------------------------------------
    initial begin
        // This prints a message every time a branch misprediction flushes the pipeline!
        $monitor("Time=%0t | PC=%h | Misprediction Flush=%b | Exception=%b", 
                 $time, dut.pc_out, dut.branch_mispredicted, exception);
    end

endmodule