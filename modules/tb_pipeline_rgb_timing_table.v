`timescale 1ns / 1ps

module tb_pipeline_rgb_timing_table;

    localparam [31:0] ACCEL_PUSH_ADDR = 32'h00012024;
    localparam [3:0] FILTER_MODE = 4'b0001;
    localparam integer CAPTURE_CYCLES = 50; 

    reg clk;
    reg reset;
    reg [15:0] sw;
    reg [7:0] rx_data_in;
    reg rx_valid_in;
    reg warm_reset_pending;

    wire [31:0] inst_mem_read_data;
    wire [31:0] dmem_read_data;
    wire [31:0] accel_rdata;
    wire [31:0] cpu_rdata_mux;
    wire [31:0] inst_mem_address;
    wire [31:0] dmem_read_address;
    wire [31:0] dmem_write_address;
    wire [31:0] dmem_write_data;
    wire [3:0]  dmem_write_byte;
    wire        dmem_read_ready;
    wire        dmem_write_ready;
    wire        exception;
    wire        dmem_we_actual;
    wire        accel_we;
    wire        vram_we;
    wire        sim_trap_we;
    wire        tx_active;
    wire        uart_txd;
    wire        warm_reset_clear;

    integer i;
    integer table_file;
    integer cycle_count; // <--- Added Watchdog Counter

    // Timing table capture variables
    reg capture_started;
    reg capture_done;
    integer capture_idx;
    
    // Arrays to capture the CPU and Hardware state
    reg [31:0] cap_pc           [0:CAPTURE_CYCLES-1];
    reg [31:0] cap_instr        [0:CAPTURE_CYCLES-1];
    reg cap_dmem_we             [0:CAPTURE_CYCLES-1];
    reg [31:0] cap_dmem_wdata   [0:CAPTURE_CYCLES-1];
    reg cap_accel_we            [0:CAPTURE_CYCLES-1];
    reg cap_valid_mac           [0:CAPTURE_CYCLES-1];
    reg [31:0] cap_accel_out    [0:CAPTURE_CYCLES-1];

    pipe pipe_u (
        .clk                (clk),
        .reset              (reset), 
        .stall              (1'b0),
        .exception          (exception),
        .pc_out             (),
        .inst_mem_is_valid  (1'b1),
        .inst_mem_read_data (inst_mem_read_data),
        .dmem_read_data_temp(cpu_rdata_mux),
        .dmem_write_valid   (1'b1),
        .dmem_read_valid    (1'b1),
        .switch_in          (sw),
        .inst_mem_address   (inst_mem_address),
        .dmem_read_ready    (dmem_read_ready),
        .dmem_read_address  (dmem_read_address),
        .dmem_write_ready   (dmem_write_ready),
        .dmem_write_address (dmem_write_address),
        .dmem_write_data    (dmem_write_data),
        .dmem_write_byte    (dmem_write_byte)
    );

    soc_interconnect bus (
        .clk                (clk),
        .reset              (reset),
        .cpu_waddr          (dmem_write_address),
        .cpu_raddr          (dmem_read_address),
        .cpu_wdata          (dmem_write_data),
        .cpu_we             (dmem_write_ready),
        .cpu_re             (dmem_read_ready),
        .cpu_rdata          (cpu_rdata_mux),
        .dmem_we            (dmem_we_actual),
        .vram_we            (vram_we),
        .accel_we           (accel_we),
        .led_we             (),
        .uart_we            (),
        .sim_trap_we        (sim_trap_we),
        .dmem_rdata         (dmem_read_data),
        .vram_rdata         (8'b0),
        .accel_rdata        (accel_rdata),
        .tx_active          (tx_active),
        .rx_data_in         (rx_data_in),
        .rx_valid_in        (rx_valid_in),
        .warm_reset_pending (warm_reset_pending),
        .warm_reset_clear   (warm_reset_clear),
        .sw_in              (sw)
    );

    stream_accel_5x5_rgb #(.IMG_WIDTH(9)) my_conv (
        .clk      (clk),
        .reset    (reset),
        .switches (sw[3:0]),
        .we       (accel_we),
        .waddr    (dmem_write_address),
        .wdata    (dmem_write_data),
        .raddr    (dmem_read_address),
        .rdata    (accel_rdata)
    );

    instr_mem IMEM (
        .clk  (clk),
        .pc   (inst_mem_address),
        .instr(inst_mem_read_data)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin

        if (reset == 1'b1 && cycle_count < 60) begin
            $display("DEBUG [Cycle %0d]: PC = 0x%08x | Instr = 0x%08x", cycle_count, inst_mem_address, inst_mem_read_data);
        end
        // WATCHDOG TIMER: Kill the simulation if it hangs
        cycle_count <= cycle_count + 1;
        if (cycle_count > 5000) begin
            $display("\nFAIL: Hard timeout reached (5000 cycles)!");
            $display("The CPU never reached the 'sw' instructions. It is likely stuck in a bootloader while loop.");
            $finish;
        end

        // The trigger: Start capturing the MOMENT the CPU pushes the first pixel to the accelerator
        if (!capture_started && accel_we && dmem_write_address == ACCEL_PUSH_ADDR) begin
            capture_started <= 1'b1;
            $display("\nINFO: CPU executed first 'sw' to Accelerator! Capturing Burst...");
        end

        if (capture_started && !capture_done && capture_idx < CAPTURE_CYCLES) begin
            cap_pc[capture_idx]         <= inst_mem_address;    // Fetch Stage Activity
            cap_instr[capture_idx]      <= inst_mem_read_data;  // Fetch Stage Activity
            cap_dmem_we[capture_idx]    <= dmem_write_ready;    // Execute Stage Activity
            cap_dmem_wdata[capture_idx] <= dmem_write_data;     // Execute Stage Activity
            cap_accel_we[capture_idx]   <= accel_we;            // Bus Activity
            cap_valid_mac[capture_idx]  <= my_conv.valid_mac;   // Hardware Activity
            cap_accel_out[capture_idx]  <= my_conv.final_pixel_reg; // Output Pixel

            if (capture_idx == CAPTURE_CYCLES-1) capture_done <= 1'b1;
            capture_idx <= capture_idx + 1;
        end
    end

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_pipeline_rgb_timing_table);
        
        cycle_count = 0;
        reset = 1'b0; 
        
        // 1. Bootloader Bypass Sequence - Start HIGH!
        sw = {1'b1, 11'b0, FILTER_MODE}; 
        
        rx_data_in = 8'h00;
        rx_valid_in = 1'b0;
        warm_reset_pending = 1'b0;

        capture_started = 1'b0;
        capture_done = 1'b0;
        capture_idx = 0;

        repeat (5) @(negedge clk);
        reset = 1'b1; // Release reset, CPU starts fetching from IMEM
        
        // Wait a bit for the CPU to enter the bootloader loop
        repeat (50) @(negedge clk);
        
        // 2. Drop SW[15] LOW to release the CPU into main()!
        sw[15] = 1'b0; 
        $display("INFO: SW[15] pulled low. CPU should jump to main() assembly burst now.");

        // Wait for the CPU to do its register setup and trigger the capture block naturally
        wait (capture_done == 1'b1);

        // Generate the VERTICAL Timing Table
        table_file = $fopen("timing_table_CPU_Burst.txt", "w");
        
        $fwrite(table_file, "CPU REGISTER BURST: 1 PIXEL/CYCLE TRACE\n");
        $fwrite(table_file, "=======================================\n");
        $fwrite(table_file, "CPU is ACTIVE. Executing 15 consecutive 'sw' assembly instructions.\n\n");

        $fwrite(table_file, "Cyc | CPU_PC     | CPU_Instr  | CPU_Exec_WE | Pushed_Pixel | Accel_WE | Val_MAC | Filtered_Out \n");
        $fwrite(table_file, "----+------------+------------+-------------+--------------+----------+---------+--------------\n");

        for (i = 0; i < CAPTURE_CYCLES; i = i + 1) begin
            $fwrite(table_file, "C%02d |", i);
            
            // CPU Pipeline Fetch Stage
            $fwrite(table_file, " 0x%08x |", cap_pc[i]);
            $fwrite(table_file, " 0x%08x |", cap_instr[i]);
            
            // CPU Pipeline Execute Stage
            $fwrite(table_file, "      %1b      |", cap_dmem_we[i]);
            
            if (cap_dmem_we[i]) $fwrite(table_file, "  0x%08x  |", cap_dmem_wdata[i]);
            else                $fwrite(table_file, "  ----------  |");

            // Accelerator Hardware Stages
            $fwrite(table_file, "    %1b     |", cap_accel_we[i]);
            $fwrite(table_file, "    %1b    |", cap_valid_mac[i]);
            
            if (cap_valid_mac[i]) $fwrite(table_file, "  0x%08x  \n", cap_accel_out[i]);
            else                  $fwrite(table_file, "  ----------  \n");
        end

        $fclose(table_file);
        $display("PASS: Timing capture complete. Wrote timing_table_CPU_Burst.txt\n");
        $finish;
    end
endmodule