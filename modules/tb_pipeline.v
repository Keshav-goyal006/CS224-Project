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

    // ADD THIS: Define switches and select a kernel
    reg [3:0] sw;
    initial begin
        sw = 4'b0111; // 0001 = Box Blur, 0010 = Edge Detect, 0100 = Sharpen
    end


    // initial begin
    //     // Specify the name of the output VCD file
    //     $dumpfile("pipeline.vcd");
    //     // Dump all variables in the testbench and its instantiated modules
    //     $dumpvars(0, tb_pipeline); 
    // end

    ////////////////////////////////////////////////////////////
    // PIPE <-> MEMORY SIGNALS
    ////////////////////////////////////////////////////////////
    wire [31:0] inst_mem_read_data;
    wire [31:0] dmem_read_data;
    wire exception;

    // =================================================================
    // 1. CPU PIPELINE
    // =================================================================
    wire [31:0] cpu_rdata_mux;
    wire [31:0] inst_mem_address;
    wire [31:0] dmem_read_address, dmem_write_address, dmem_write_data;
    wire [3:0]  dmem_write_byte;
    wire        dmem_read_ready, dmem_write_ready;

    pipe pipe_u (
        .clk                 (clk),
        .reset               (reset),
        .stall               (1'b0),
        .exception           (exception),
        .pc_out              (),
        
        .inst_mem_is_valid   (1'b1),
        .inst_mem_read_data  (inst_mem_read_data),
        .inst_mem_address    (inst_mem_address),
        
        .dmem_read_valid     (1'b1),
        .dmem_read_data_temp (cpu_rdata_mux), // <--- CPU reads from the Interconnect!
        .dmem_read_ready     (dmem_read_ready),
        .dmem_read_address   (dmem_read_address),
        
        .dmem_write_valid    (1'b1),
        .dmem_write_ready    (dmem_write_ready),
        .dmem_write_address  (dmem_write_address),
        .dmem_write_data     (dmem_write_data),
        .dmem_write_byte     (dmem_write_byte)
    );

    // =================================================================
    // 2. SOC INTERCONNECT
    // =================================================================
    wire dmem_we_actual, accel_we, vram_we, led_we, uart_we, sim_trap_we;
    wire [31:0] accel_rdata;
    wire tx_active;
    wire uart_txd; // Dummy wire for simulation

    soc_interconnect bus (
        .clk        (clk),        // <-- ADD THIS
        .reset      (reset),      // <-- ADD THIS
        .cpu_waddr  (dmem_write_address), 
        .cpu_raddr  (dmem_read_address),  
        .cpu_wdata  (dmem_write_data),
        .cpu_we     (dmem_write_ready), 
        .cpu_re     (dmem_read_ready),
        .cpu_rdata  (cpu_rdata_mux),     

        .dmem_we    (dmem_we_actual),
        .vram_we    (vram_we),
        .accel_we   (accel_we),
        .led_we     (led_we),
        .uart_we    (uart_we),
        .sim_trap_we(sim_trap_we),

        .dmem_rdata (dmem_read_data),
        .vram_rdata (8'b0), // We don't need VRAM/VGA in simulation
        .accel_rdata(accel_rdata),
        .uart_rdata ({31'b0, tx_active}) 
    );

    // =================================================================
    // 3. HARDWARE ACCELERATOR
    // =================================================================
    // conv_accelerator my_conv (
    //     .clk    (clk),
    //     .reset  (reset),
    //     .we     (accel_we),
    //     .waddr  (dmem_write_address),
    //     .wdata  (dmem_write_data),
    //     .raddr  (dmem_read_address),
    //     .rdata  (accel_rdata)
    // );
    // stream_accel #(.IMG_WIDTH(64)) my_conv (
    //     .clk      (clk),
    //     .reset    (reset),
    //     .switches (sw), // Hook up the testbench switches!
    //     .we       (accel_we),
    //     .waddr    (dmem_write_address),
    //     .wdata    (dmem_write_data),
    //     .raddr    (dmem_read_address),
    //     .rdata    (accel_rdata)
    // );

    // =================================================================
    // 3. HARDWARE ACCELERATOR (5x5 Upgrade!)
    // =================================================================
    stream_accel_5x5 #(.IMG_WIDTH(64)) my_conv (
        .clk      (clk),         // Use the raw testbench clock
        .reset    (reset),
        .switches (sw),          // Pass the simulated testbench switches
        .we       (accel_we),
        .waddr    (dmem_write_address),
        .wdata    (dmem_write_data),
        .raddr    (dmem_read_address),
        .rdata    (accel_rdata)
    );

    // =================================================================
    // 4. UART TRANSMITTER
    // =================================================================
    uart_tx #( .CLKS_PER_BIT(2) ) my_uart (
        .clk        (clk),
        .reset      (reset),
        .tx_start   (uart_we), 
        .tx_data    (dmem_write_data[7:0]),
        .tx_active  (tx_active),
        .tx_serial  (uart_txd) 
    );

    // =================================================================
    // 5. MEMORY
    // =================================================================
    instr_mem IMEM (.clk(clk), .pc(inst_mem_address), .instr(inst_mem_read_data));
    
    data_mem DMEM (
        .clk(clk), 
        .re(dmem_read_ready), 
        .raddr(dmem_read_address), 
        .rdata(dmem_read_data), 
        .we(dmem_we_actual), // Protected by the interconnect
        .waddr(dmem_write_address), 
        .wdata(dmem_write_data), 
        .wstrb(dmem_write_byte)
    );

    ////////////////////////////////////////////////////////////
    // PRINT PIPELINE OUTPUT & STOP CONDITION
    ////////////////////////////////////////////////////////////
    reg program_started = 0;

    always @(posedge clk) begin
        // Only run if the processor is active (reset is off)
        if (reset == 1) begin
            
            // Stop the simulation if it loops back to the beginning
            if (program_started == 1 && inst_mem_address == 32'h00000000) begin
                $display("All instructions are Fetched - CPU Looped back to 0x0.");
                $finish;
            end
            
            // Track that the program has safely started
            if (inst_mem_address > 0) begin
                program_started = 1;
            end
        end
    end

    ////////////////////////////////////////////////////////////
    // SPY ON THE UART & CATCH THE 19,200 PIXELS
    ////////////////////////////////////////////////////////////
    integer file_out;
    integer pixel_count;


    initial begin
        // Open a text file to save the pixels
        file_out = $fopen("simulated_pixels.txt", "w");
        pixel_count = 0;
    end

    // -------------------------------------------------------------------------
    // UART SPY: WATCH ADDRESS 0x5000 AND PRINT CHARACTERS
    // -------------------------------------------------------------------------
    // always @(posedge clk) begin
    //     if (reset == 1 && dmem_write_ready && dmem_write_address == 32'h00005000) begin
    //         // %c tells Vivado to print the number as an ASCII letter (e.g., 65 = 'A')
    //         // $write prints on the same line, instead of adding a newline every letter
    //         $write("%c", dmem_write_data[7:0]);
    //     end
    // end

    always @(posedge clk) begin
        // In code_vision.c, the UART TX DATA register is at 0x00005000.
        // Whenever the CPU writes to this address, intercept the pixel!
        if (dmem_write_ready && dmem_write_address == 32'h00005000) begin
            
            // Write the 8-bit pixel to the text file
            $fdisplay(file_out, "%d", dmem_write_data[7:0]);
            pixel_count = pixel_count + 1;
            
            // Print progress to the terminal every 1,000 pixels 
            // so you know the simulation hasn't frozen
            if (pixel_count % 1000 == 0) begin
                $display("Simulated %0d / 19200 pixels...", pixel_count);
            end

            // Once we hit exactly 160x120 pixels, stop the simulation!
            if (pixel_count == 3072) begin
                $display("SUCCESS: All 3072 pixels generated!");
                $fclose(file_out);
                $finish;
            end
        end
    end

////////////////////////////////////////////////////////////
    // DEBUG: SANITY CHECKS & HEARTBEAT MONITOR
    ////////////////////////////////////////////////////////////
    
    // 1. Check if the memory actually loaded!
    initial begin
        #10; // Wait 1 clock cycle
        if (IMEM.imem[0] === 32'bx) begin
            $display("===========================================================");
            $display(" CRITICAL ERROR: imem.hex DID NOT LOAD!");
            $display(" Check the absolute path in your memory.v file.");
            $display("===========================================================");
            $finish;
        end else begin
            $display("SUCCESS: imem.hex loaded correctly. CPU is starting...");
        end
    end

    ////////////////////////////////////////////////////////////
    // ACCELERATOR DIAGNOSTIC MONITOR
    ////////////////////////////////////////////////////////////
    always @(posedge clk) begin
        if (dmem_write_ready && dmem_write_address == 32'h00004000) begin
            $display("========================================");
            $display(" ACCEL TEST RESULT: %d", dmem_write_data);
            $display("========================================");
            if (dmem_write_data == 90) 
                $display(" STATUS: SUCCESS (Hardware MAC is working!)");
            else if (dmem_write_data == 0)
                $display(" STATUS: FAILED (Read returned 0. Check Interconnect/Hazards)");
            else
                $display(" STATUS: WRONG DATA (Check Accelerator logic)");
            $finish;
        end
    end

    // 2. Track exactly where the CPU freezes
    // always @(posedge clk) begin
    //     if (dmem_write_ready) begin
            
    //         // Did it successfully write the weights?
    //         if (dmem_write_address == 32'h00002000)
    //             $display("HEARTBEAT: CPU successfully started writing WEIGHTS...");
            
    //         // Did it successfully push the first pixel?
    //         if (dmem_write_address == 32'h00002040)
    //             $display("HEARTBEAT: CPU successfully pushed PIXEL to accelerator...");
                
    //         // Did it successfully trigger the UART?
    //         if (dmem_write_address == 32'h00005000) begin
    //             $display("HEARTBEAT: UART Transmitting pixel %0d...", pixel_count);
    //         end
    //     end
    // end

    // 2. Track exactly where the CPU freezes
    always @(posedge clk) begin
        if (dmem_write_ready) begin
            
            // Did it successfully push the first pixel?
            // (Notice the new address: 0x00020024)
            if (dmem_write_address == 32'h00002024)
                $display("HEARTBEAT: CPU successfully pushed PIXEL to streaming accelerator...");
                
            // Did it successfully trigger the UART?
            // (Notice the new address: 0x00023000)
            if (dmem_write_address == 32'h00005000) begin
                $display("HEARTBEAT: UART Transmitting pixel %0d...", pixel_count);
            end
        end
    end

    always @(posedge clk)
    if (dmem_read_address == 32'h00002028)
        $display("[%0t] Accelerator true pixel: %0d  CPU sees: %0d",
                 $time, stream_accel_5x5.final_pixel, stream_accel_5x5.rdata);


endmodule