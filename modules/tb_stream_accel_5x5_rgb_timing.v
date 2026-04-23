`timescale 1ns / 1ps

module tb_stream_accel_5x5_rgb_timing;

    // Inputs to the accelerator
    reg clk;
    reg reset;
    reg [3:0] switches;
    reg we;
    reg [31:0] waddr;
    reg [31:0] wdata;
    reg [31:0] raddr;
    
    // Outputs from the accelerator
    wire [31:0] rdata;

    // Timing measurement
    integer cycle_count;
    integer output_file;

    // 1. Instantiate the Device Under Test (DUT)
    stream_accel_5x5_rgb #(.IMG_WIDTH(5)) dut (
        .clk(clk),
        .reset(reset),
        .switches(switches),
        .we(we),
        .waddr(waddr),
        .wdata(wdata),
        .raddr(raddr),
        .rdata(rdata)
    );

    // 2. Generate a 100MHz Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 3. The Test Routine
    integer i, row, col;
    reg [7:0] pix_r;
    reg [7:0] pix_g;
    initial begin
        // Open output file for logging
        output_file = $fopen("stream_accel_timing_log.txt", "w");
        
        // Initialize everything to 0
        reset = 0;
        we = 0; 
        waddr = 0; 
        wdata = 0; 
        raddr = 0;
        cycle_count = 0;
        
        // Set to Gaussian Blur kernel (switch mode 0001)
        switches = 4'b0001;
        
        #20;
        reset = 1; // Release reset (active-low reset)
        #20;

        $fwrite(output_file, "=================================================\n");
        $fwrite(output_file, " STREAM_ACCEL_5x5_RGB TIMING DIAGRAM - 9x9 Image\n");
        $fwrite(output_file, "=================================================\n\n");
        $fwrite(output_file, "Kernel Mode: 0001 (Gaussian Blur)\n");
        $fwrite(output_file, "Image Size: 5x5 pixels = 81 total pixels\n");
        $fwrite(output_file, "Window: 5x5 (4 line buffers + live pixel)\n");
        $fwrite(output_file, "Warmup Pixels: (2 * 5) + 3 = 13 pixels\n");
        $fwrite(output_file, "Output Pixels: 25 - 12 = 13 valid outputs\n\n");
        $fwrite(output_file, "Format: CYCLE | DATA_PUSH | PIXEL_IN | OUTPUT | WINDOW_VALID\n");
        $fwrite(output_file, "---------+----------+-----------+----------+-----------\n\n");

        $display("\n=================================================");
        $display(" STARTING STREAM_ACCEL_5x5_RGB TIMING TEST");
        $display(" 5x5 Image with Gaussian Blur Kernel");
        $display("=================================================\n");

        // Push exactly 9x9 = 81 pixels
        for (i = 0; i < 25; i = i + 1) begin
            
            // Calculate row and column for readability
            row = (i * 5)%256;
            col = i % 5;
            
            // PUSH PIXEL
            we = 1; 
            waddr = 32'h00012024; // Pixel In Address
            // Create test pattern: gradient RGB image
            // Red increases left to right
            // Green increases top to bottom
            // Blue is constant
            pix_r = row * 28;
            pix_g = col * 28;
            wdata = {8'h00, 
                     pix_r,           // R = row * 28 (0-224)
                     pix_g,           // G = col * 28 (0-224)
                     8'd128};         // B = 128
            #10;

            // READ RESULT
            we = 0; 
            raddr = 32'h00012028; // MAC Result Address
            #10;

            cycle_count = cycle_count + 2;

            // Determine if window is valid (after warmup)
            if (i >= 13) begin
                $fwrite(output_file, "%-9d | %08h | R=%3d G=%3d B=%3d | %08h | VALID\n",
                    cycle_count, wdata, (row*28), (col*28), 128, rdata);
                
                if (i == 13)
                    $display("Pixel %0d (Row %0d, Col %0d) - First Valid Output: 0x%08h", i, row, col, rdata);
                if (i == 25)
                    $display("Pixel %0d (Row %0d, Col %0d) - Last Valid Output:  0x%08h", i, row, col, rdata);
            end else begin
                $fwrite(output_file, "%-9d | %08h | R=%3d G=%3d B=%3d | %08h | WARMUP\n",
                    cycle_count, wdata, (row*28), (col*28), 128, rdata);
                
                if (i == 0)
                    $display("Pixel %0d (Row %0d, Col %0d) - Starting Warmup: 0x%08h (Expected: Low)", i, row, col, rdata);
                if (i == 12)
                    $display("Pixel %0d (Row %0d, Col %0d) - Last Warmup Pixel: 0x%08h", i, row, col, rdata);
            end
        end

        // Add padding pixels for final output reads (no new pixels pushed)
        for (i = 25; i < 25 + 5; i = i + 1) begin
            // PUSH PADDING (zeros)
            we = 1; 
            waddr = 32'h00012024;
            wdata = 32'h00000000;
            #10;

            // READ RESULT
            we = 0; 
            raddr = 32'h00012028;
            #10;

            cycle_count = cycle_count + 2;
            $fwrite(output_file, "%-9d | %08h | PAD PIXEL   | %08h | FLUSH\n",
                cycle_count, 32'h0, rdata);
        end

        $fwrite(output_file, "\n=================================================\n");
        $fwrite(output_file, " TEST COMPLETE\n");
        $fwrite(output_file, "=================================================\n");

        $display("\n=================================================");
        $display(" TEST COMPLETE");
        $display(" Timing log written to: stream_accel_timing_log.txt");
        $display("=================================================\n");

        $fclose(output_file);
        $finish;
    end

endmodule
