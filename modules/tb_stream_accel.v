`timescale 1ns / 1ps

module tb_stream_accel;

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

    // 1. Instantiate the Device Under Test (DUT)
    stream_accel #(.IMG_WIDTH(64)) dut (
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
    integer i;
    initial begin
        // Initialize everything to 0
        reset = 1;
        we = 0; 
        waddr = 0; 
        wdata = 0; 
        raddr = 0;
        
        // Turn on the Box Blur Kernel (w=1, divide by 8)
        switches = 4'b0001; 
        
        #20;
        reset = 0; // Release reset
        #20;

        $display("\n=================================================");
        $display(" STARTING STREAMING ACCELERATOR UNIT TEST");
        $display(" Pumping 192 Pure White Pixels (255) into hardware...");
        $display("=================================================\n");

        // Push exactly 3 rows of pixels (64 pixels * 3 rows = 192)
        for (i = 0; i < 192; i = i + 1) begin
            
            // ----------------------------------------------------
            // CLOCK CYCLE 1: PUSH PIXEL
            // ----------------------------------------------------
            we = 1; 
            waddr = 32'h00002024; // Pixel In Address
            wdata = 32'd255;      // Pure White Pixel
            #10; 

            // ----------------------------------------------------
            // CLOCK CYCLE 2: READ RESULT
            // ----------------------------------------------------
            we = 0; 
            raddr = 32'h00002028; // MAC Result Address
            #10; 

            // Only print critical checkpoints so we don't flood the console
            if (i == 0)   
                $display("Pixel %0d   (Row 0 Start) : Out = %0d (Expected: Low. Line Buffers empty)", i, rdata);
            if (i == 64)  
                $display("Pixel %0d  (Row 1 Start) : Out = %0d (Expected: Med. Line Buffer 1 full)", i, rdata);
            if (i == 128) 
                $display("Pixel %0d (Row 2 Start) : Out = %0d (Expected: 255. Both Line Buffers full!)", i, rdata);
            if (i == 130) 
                $display("Pixel %0d (Row 2 Middle): Out = %0d (Expected: 255. Perfect 3x3 Window!)", i, rdata);
        end

        $display("\n=================================================");
        $display(" TEST COMPLETE");
        $display("=================================================\n");
        $finish;
    end

endmodule