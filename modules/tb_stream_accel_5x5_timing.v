`timescale 1ns / 1ps

module tb_stream_accel_5x5_timing;

    reg clk;
    reg reset;
    reg [3:0] switches;
    reg we;
    reg [31:0] waddr;
    reg [31:0] wdata;
    reg [31:0] raddr;

    wire [31:0] rdata;

    integer cycle_count;
    integer output_file;
    integer i;
    integer row;
    integer col;
    integer pixel_val;

    localparam IMG_W = 9;
    localparam IMG_H = 9;
    localparam TOTAL_PIXELS = IMG_W * IMG_H;
    localparam WARMUP_PIXELS = (4 * IMG_W) + 4;

    stream_accel_5x5 #(.IMG_WIDTH(IMG_W)) dut (
        .clk(clk),
        .reset(reset),
        .switches(switches),
        .we(we),
        .waddr(waddr),
        .wdata(wdata),
        .raddr(raddr),
        .rdata(rdata)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        output_file = $fopen("stream_accel_5x5_timing_log.txt", "w");

        reset = 0;
        switches = 4'b0001; // 5x5 gaussian
        we = 0;
        waddr = 32'd0;
        wdata = 32'd0;
        raddr = 32'd0;
        cycle_count = 0;

        #20;
        reset = 1;
        #20;

        $fwrite(output_file, "=================================================\n");
        $fwrite(output_file, " STREAM_ACCEL_5x5 TIMING DIAGRAM - 9x9 Image\n");
        $fwrite(output_file, "=================================================\n\n");
        $fwrite(output_file, "Kernel Mode: 0001 (Gaussian Blur)\n");
        $fwrite(output_file, "Image Size: 9x9 pixels = 81 total pixels\n");
        $fwrite(output_file, "Warmup Pixels: (4 * 9) + 4 = 40 pixels\n");
        $fwrite(output_file, "Format: CYCLE | DATA_PUSH | PIXEL_IN | OUTPUT | WINDOW_VALID\n");
        $fwrite(output_file, "---------+----------+-----------+----------+-----------\n\n");

        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            row = i / IMG_W;
            col = i % IMG_W;
            pixel_val = (row * 24) + (col * 4);

            we = 1;
            waddr = 32'h00012024;
            wdata = pixel_val[7:0];
            #10;

            we = 0;
            raddr = 32'h00012028;
            #10;

            cycle_count = cycle_count + 2;

            if (i >= WARMUP_PIXELS) begin
                $fwrite(output_file, "%-9d | %08h | P=%3d      | %08h | VALID\n",
                    cycle_count, wdata, pixel_val, rdata);
            end else begin
                $fwrite(output_file, "%-9d | %08h | P=%3d      | %08h | WARMUP\n",
                    cycle_count, wdata, pixel_val, rdata);
            end
        end

        for (i = 0; i < 8; i = i + 1) begin
            we = 1;
            waddr = 32'h00012024;
            wdata = 32'h00000000;
            #10;

            we = 0;
            raddr = 32'h00012028;
            #10;

            cycle_count = cycle_count + 2;
            $fwrite(output_file, "%-9d | %08h | PAD        | %08h | FLUSH\n",
                cycle_count, 32'h00000000, rdata);
        end

        $fwrite(output_file, "\n=================================================\n");
        $fwrite(output_file, " TEST COMPLETE\n");
        $fwrite(output_file, "=================================================\n");

        $fclose(output_file);
        $finish;
    end

endmodule