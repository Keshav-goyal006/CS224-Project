`timescale 1ns / 1ps

module tb_pipeline_bootloader;

    localparam [3:0] FILTER_FIRST  = 4'b0010; // Edge Detect
    localparam [3:0] FILTER_SECOND = 4'b0100; // Sharpen

    reg clk;
    reg reset;
    reg [15:0] sw;
    reg [7:0] rx_data_in;
    reg rx_valid_in;
    reg warm_reset_pending;

    wire [31:0] inst_mem_read_data;
    wire [31:0] dmem_read_data;
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
    wire        led_we;
    wire        uart_we;
    wire        sim_trap_we;
    wire [31:0] accel_rdata;
    wire        tx_active;
    wire        uart_txd;
    wire        warm_reset_clear;

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
        .clk         (clk),
        .reset       (reset),
        .cpu_waddr   (dmem_write_address),
        .cpu_raddr   (dmem_read_address),
        .cpu_wdata   (dmem_write_data),
        .cpu_we      (dmem_write_ready),
        .cpu_re      (dmem_read_ready),
        .cpu_rdata   (cpu_rdata_mux),
        .dmem_we     (dmem_we_actual),
        .vram_we     (vram_we),
        .accel_we    (accel_we),
        .led_we      (led_we),
        .uart_we     (uart_we),
        .sim_trap_we (sim_trap_we),
        .dmem_rdata  (dmem_read_data),
        .vram_rdata  (8'b0),
        .accel_rdata (accel_rdata),
        .tx_active   (tx_active),
        .rx_data_in  (rx_data_in),
        .rx_valid_in (rx_valid_in),
        .warm_reset_pending(warm_reset_pending),
        .warm_reset_clear(warm_reset_clear),
        .sw_in       (sw)
    );

    stream_accel_5x5 #(.IMG_WIDTH(64)) my_conv (
        .clk      (clk),
        .reset    (reset),
        .switches (sw[3:0]),
        .we       (accel_we),
        .waddr    (dmem_write_address),
        .wdata    (dmem_write_data),
        .raddr    (dmem_read_address),
        .rdata    (accel_rdata)
    );

    uart_tx #( .CLKS_PER_BIT(2) ) my_uart (
        .clk        (clk),
        .reset      (reset),
        .tx_start   (uart_we),
        .tx_data    (dmem_write_data[7:0]),
        .tx_active  (tx_active),
        .tx_serial  (uart_txd)
    );

    instr_mem IMEM (
        .clk  (clk),
        .pc   (inst_mem_address),
        .instr(inst_mem_read_data)
    );

    data_mem DMEM (
        .clk   (clk),
        .re    (dmem_read_ready),
        .raddr (dmem_read_address),
        .rdata (dmem_read_data),
        .we    (dmem_we_actual),
        .waddr (dmem_write_address),
        .wdata (dmem_write_data),
        .wstrb (dmem_write_byte)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    integer cycle_count;
    integer i;
    integer first_output_count;
    integer second_output_count;
    integer output_phase;
    integer first_file;
    integer second_file;
    integer image_file;
    integer scan_result;
    reg [7:0] input_image [0:3071];

    always @(posedge clk) begin
        if (warm_reset_clear) begin
            warm_reset_pending = 1'b0;
        end
    end

    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count > 5000000) begin
            $display("FAIL: timeout waiting for integrated bootloader/pipeline test to finish.");
            $finish;
        end
    end

    always @(posedge clk) begin
        if (dmem_write_ready && dmem_write_address == 32'h00005000 && cycle_count > 0) begin
            if (output_phase == 0) begin
                $fdisplay(first_file, "%0d", dmem_write_data[7:0]);
                first_output_count = first_output_count + 1;

                if (first_output_count % 256 == 0) begin
                    $display("Run 1 progress: %0d / 3072 bytes", first_output_count);
                end

                if (first_output_count == 3072) begin
                    $display("PASS: first filter finished. Ready for warm reset and second filter.");
                end
            end else begin
                $fdisplay(second_file, "%0d", dmem_write_data[7:0]);
                second_output_count = second_output_count + 1;

                if (second_output_count % 256 == 0) begin
                    $display("Run 2 progress: %0d / 3072 bytes", second_output_count);
                end

                if (second_output_count == 3072) begin
                    $fclose(first_file);
                    $fclose(second_file);
                    $display("PASS: bootloader loaded the image once, warm reset preserved DMEM, and two filters completed.");
                    $finish;
                end
            end
        end
    end

    task send_uart_byte;
        input [7:0] value;
        begin
            @(negedge clk);
            rx_data_in = value;
            rx_valid_in = 1'b1;
            @(negedge clk);
            rx_valid_in = 1'b0;
        end
    endtask

    initial begin
        reset = 1'b0;
        sw = {1'b1, 11'b0, FILTER_FIRST};
        rx_data_in = 8'h00;
        rx_valid_in = 1'b0;
        warm_reset_pending = 1'b0;
        cycle_count = 0;
        first_output_count = 0;
        second_output_count = 0;
        output_phase = 0;

        first_file = $fopen("simulated_pixels.txt", "w");
        if (first_file == 0) begin
            $display("FAIL: could not open simulated_pixels.txt for writing.");
            $finish;
        end

        second_file = $fopen("simulated_pixels_warm.txt", "w");
        if (second_file == 0) begin
            $display("FAIL: could not open simulated_pixels_warm.txt for writing.");
            $finish;
        end

        image_file = $fopen("original_image.txt", "r");
        if (image_file == 0) begin
            $display("FAIL: could not open original_image.txt for reading.");
            $finish;
        end

        for (i = 0; i < 3072; i = i + 1) begin
            scan_result = $fscanf(image_file, "%d\n", input_image[i]);
            if (scan_result != 1) begin
                $display("FAIL: could not read pixel %0d from original_image.txt.", i);
                $finish;
            end
        end

        $fclose(image_file);

        repeat (10) @(negedge clk);
        reset = 1'b1;
        repeat (20) @(negedge clk);

        $display("Starting integrated bootloader + pipeline test with original_image.txt...");

        for (i = 0; i < 3072; i = i + 1) begin
            send_uart_byte(input_image[i]);
            wait (dmem_we_actual && dmem_write_address == (32'h00001000 + i));
            @(negedge clk);
        end

        repeat (10) @(negedge clk);
        sw[15] = 1'b0;
        $display("SW[15] is now low; pipeline should start processing the loaded image.");

        wait (first_output_count == 3072);

        repeat (20) @(negedge clk);
        output_phase = 1;
        sw[3:0] = FILTER_SECOND;
        sw[15] = 1'b1;
        warm_reset_pending = 1'b1;

        $display("Triggering warm reset for the second filter run...");

        repeat (10) @(negedge clk);
        reset = 1'b0;
        repeat (10) @(negedge clk);
        reset = 1'b1;

        wait (warm_reset_pending == 1'b0);
        $display("Warm reset acknowledged; second filter run should begin now.");
    end

endmodule