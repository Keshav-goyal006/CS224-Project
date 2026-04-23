`timescale 1ns / 1ps

module tb_pipeline_bootloader_9x9_latency;

    localparam integer IMG_WIDTH = 9;
    localparam integer IMG_HEIGHT = 9;
    localparam integer INPUT_BYTES = IMG_WIDTH * IMG_HEIGHT * 4;
    localparam integer TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;
    localparam integer WARMUP_PIXELS = (2 * IMG_WIDTH) + 3;
    localparam integer PIXEL_FIFO_DEPTH = 256;
    localparam integer BOOTLOADER_IMAGE_BYTES = 49152;

    localparam [31:0] ACCEL_PUSH_ADDR = 32'h00012024;
    localparam [31:0] UART_TX_ADDR = 32'h00015000;

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
    wire        led_we;
    wire        uart_we;
    wire        sim_trap_we;
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
        .led_we             (led_we),
        .uart_we            (uart_we),
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

    stream_accel_5x5_rgb #(.IMG_WIDTH(IMG_WIDTH)) accel_u (
        .clk      (clk),
        .reset    (reset),
        .switches (sw[3:0]),
        .we       (accel_we),
        .waddr    (dmem_write_address),
        .wdata    (dmem_write_data),
        .raddr    (dmem_read_address),
        .rdata    (accel_rdata)
    );

    uart_tx #(.CLKS_PER_BIT(2)) uart_u (
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
    integer image_file;
    integer scan_result;
    integer log_file;

    reg [7:0] input_image [0:INPUT_BYTES-1];

    // Pixel mapping FIFO: one entry per output-producing push (i >= warmup).
    integer pixel_push_cycle_fifo [0:PIXEL_FIFO_DEPTH-1];
    integer pixel_fifo_head;
    integer pixel_fifo_tail;
    integer pixel_fifo_count;

    integer push_count;
    integer output_count;
    integer uart_byte_phase;

    integer start_push_cycle;
    integer end_uart_cycle;

    integer lat_push_to_uart;

    integer min_push_to_uart;
    integer max_push_to_uart;
    integer sum_push_to_uart;

    task send_uart_byte_until_dmem_write;
        input [7:0] value;
        input [31:0] expected_addr;
        integer wait_cycles;
        begin
            @(negedge clk);
            rx_data_in = value;
            rx_valid_in = 1'b1;

            wait_cycles = 0;
            while (!(dmem_we_actual && dmem_write_address == expected_addr)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
                if (wait_cycles > 200000) begin
                    $display("FAIL: timeout waiting for bootloader DMEM write at addr 0x%08x.", expected_addr);
                    $finish;
                end
            end

            rx_valid_in = 1'b0;
            @(negedge clk);
        end
    endtask

    always @(posedge clk) begin
        if (warm_reset_clear) begin
            warm_reset_pending <= 1'b0;
        end
    end

    // Keep a monotonically increasing cycle counter.
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count > 120000000) begin
            $display("FAIL: timeout in 9x9 latency testbench.");
            $finish;
        end
    end

    // Latency instrumentation.
    always @(posedge clk) begin
        if (!reset) begin
            // no-op during reset
        end else begin
            if (dmem_write_ready) begin
                // Track only accelerator pushes that will eventually produce an output pixel.
                if (dmem_write_address == ACCEL_PUSH_ADDR) begin
                    push_count = push_count + 1;

                    if (push_count > WARMUP_PIXELS) begin
                        if (pixel_fifo_count < PIXEL_FIFO_DEPTH) begin
                            pixel_push_cycle_fifo[pixel_fifo_tail] = cycle_count;
                            pixel_fifo_tail = (pixel_fifo_tail + 1) % PIXEL_FIFO_DEPTH;
                            pixel_fifo_count = pixel_fifo_count + 1;
                        end else begin
                            $display("FAIL: pixel latency FIFO overflow.");
                            $finish;
                        end
                    end
                end

                // Every 3rd UART write is one completed RGB pixel.
                if (dmem_write_address == UART_TX_ADDR) begin
                    uart_byte_phase = uart_byte_phase + 1;
                    if (uart_byte_phase == 3) begin
                        uart_byte_phase = 0;

                        if (pixel_fifo_count <= 0) begin
                            $display("FAIL: UART output pixel with empty pixel FIFO.");
                            $finish;
                        end

                        start_push_cycle = pixel_push_cycle_fifo[pixel_fifo_head];
                        pixel_fifo_head = (pixel_fifo_head + 1) % PIXEL_FIFO_DEPTH;
                        pixel_fifo_count = pixel_fifo_count - 1;

                        end_uart_cycle = cycle_count;
                        output_count = output_count + 1;

                        lat_push_to_uart = end_uart_cycle - start_push_cycle;

                        if (output_count == 1) begin
                            min_push_to_uart = lat_push_to_uart;
                            max_push_to_uart = lat_push_to_uart;
                        end else begin
                            if (lat_push_to_uart < min_push_to_uart) min_push_to_uart = lat_push_to_uart;
                            if (lat_push_to_uart > max_push_to_uart) max_push_to_uart = lat_push_to_uart;
                        end

                        sum_push_to_uart = sum_push_to_uart + lat_push_to_uart;

                        $fdisplay(log_file,
                            "pixel=%0d push_commit=%0d uart_end=%0d lat_push_to_uart=%0d",
                            output_count - 1,
                            start_push_cycle,
                            end_uart_cycle,
                            lat_push_to_uart
                        );

                        if ((output_count % 16) == 0) begin
                            $display("Progress: captured %0d / %0d output-pixel latencies.", output_count, TOTAL_PIXELS);
                        end

                        if (output_count == TOTAL_PIXELS) begin
                            $fdisplay(log_file, "");
                            $fdisplay(log_file,
                                "summary total_pixels=%0d push_to_uart_min=%0d push_to_uart_max=%0d push_to_uart_avg=%0d",
                                TOTAL_PIXELS,
                                min_push_to_uart,
                                max_push_to_uart,
                                (sum_push_to_uart / TOTAL_PIXELS)
                            );

                            $display("PASS: captured %0d output pixels.", TOTAL_PIXELS);
                            $display("Latency ACCEL_PUSH commit->UART end: min=%0d max=%0d avg=%0d cycles",
                                min_push_to_uart,
                                max_push_to_uart,
                                (sum_push_to_uart / TOTAL_PIXELS)
                            );

                            $fclose(log_file);
                            $finish;
                        end
                    end
                end
            end
        end
    end

    initial begin
        reset = 1'b0;
        sw = 16'h8001; // Bootloader enabled (SW[15]=1), Gaussian blur mode.
        rx_data_in = 8'h00;
        rx_valid_in = 1'b0;
        warm_reset_pending = 1'b0;

        cycle_count = 0;
        push_count = 0;
        output_count = 0;
        uart_byte_phase = 0;

        pixel_fifo_head = 0;
        pixel_fifo_tail = 0;
        pixel_fifo_count = 0;

        min_push_to_uart = 0;
        max_push_to_uart = 0;
        sum_push_to_uart = 0;

        log_file = $fopen("latency_9x9_ifid_to_uart.txt", "w");
        if (log_file == 0) begin
            $display("FAIL: could not open latency_9x9_ifid_to_uart.txt");
            $finish;
        end
        $fdisplay(log_file, "# 9x9 per-pixel latency log");
        $fdisplay(log_file, "# warmup_pixels=%0d total_pixels=%0d", WARMUP_PIXELS, TOTAL_PIXELS);
        $fdisplay(log_file, "# fields: pixel push_commit uart_end lat_push_to_uart");

        image_file = $fopen("image_9x9_rgb_bytes.txt", "r");
        if (image_file == 0) begin
            $display("FAIL: could not open image_9x9_rgb_bytes.txt for reading.");
            $finish;
        end

        for (i = 0; i < INPUT_BYTES; i = i + 1) begin
            scan_result = $fscanf(image_file, "%d\n", input_image[i]);
            if (scan_result != 1) begin
                $display("FAIL: could not read byte %0d from image_9x9_rgb_bytes.txt.", i);
                $finish;
            end
        end
        $fclose(image_file);

        repeat (10) @(negedge clk);
        reset = 1'b1;
        $display("INFO: Reset released; bootloader should start now with SW[15]=%b.", sw[15]);
        repeat (20) @(negedge clk);

        $display("INFO: Sending %0d image bytes to bootloader for 9x9 image.", INPUT_BYTES);
        for (i = 0; i < INPUT_BYTES; i = i + 1) begin
            send_uart_byte_until_dmem_write(input_image[i], (32'h00001000 + i));
            if (i == 0) begin
                $display("INFO: First bootloader byte accepted at DMEM address 0x%08x.", (32'h00001000 + i));
            end else if ((i % 64) == 0) begin
                $display("INFO: UART load progress: %0d / %0d bytes accepted.", i, INPUT_BYTES);
            end
        end

        for (i = INPUT_BYTES; i < BOOTLOADER_IMAGE_BYTES; i = i + 1) begin
            send_uart_byte_until_dmem_write(8'h00, (32'h00001000 + i));
            if ((i % 4096) == 0) begin
                $display("INFO: UART padding progress: %0d / %0d bytes accepted.", i, BOOTLOADER_IMAGE_BYTES);
            end
        end

        repeat (10) @(negedge clk);
        sw[15] = 1'b0;
        $display("INFO: SW[15] is now low; pipeline should start processing the loaded 9x9 image.");
        $display("INFO: UART image load complete. Waiting for latency capture.");
    end

endmodule
