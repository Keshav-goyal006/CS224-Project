`timescale 1ns / 1ps

module tb_pipeline_vga_bootloader;

    localparam [3:0] FILTER_MODE = 4'b1000; // Erosion / morphological min-path
    localparam integer INPUT_BYTES = 49152;
    localparam integer OUTPUT_PIXELS = 12288;
    localparam integer OUT_IMG_WIDTH = 128;
    localparam integer OUT_IMG_HEIGHT = 96;

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

    // VGA path signals
    wire [9:0] vga_x;
    wire [9:0] vga_y;
    wire [9:0] vga_h_count;
    wire [9:0] vga_v_count;
    wire video_on;
    wire [23:0] vga_pixel_rgb;
    wire [7:0]  vga_pixel_data;
    wire [3:0]  vga_r;
    wire [3:0]  vga_g;
    wire [3:0]  vga_b;
    wire        vga_hs;
    wire        vga_vs;

    wire [15:0] vram_write_addr = dmem_write_address[15:2];
    wire [15:0] vram_read_addr  = ((vga_y >> 2) * OUT_IMG_WIDTH) + (vga_x >> 2);
    wire        valid_draw_area = video_on && (vga_x < (OUT_IMG_WIDTH << 2)) && (vga_y < (OUT_IMG_HEIGHT << 2));

    assign vga_pixel_data = vga_pixel_rgb[7:0];
    assign vga_r = valid_draw_area ? vga_pixel_rgb[23:20] : 4'h0;
    assign vga_g = valid_draw_area ? vga_pixel_rgb[15:12] : 4'h0;
    assign vga_b = valid_draw_area ? vga_pixel_rgb[7:4]   : 4'h0;

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
        .vram_rdata         (vga_pixel_data),
        .accel_rdata        (accel_rdata),
        .tx_active          (tx_active),
        .rx_data_in         (rx_data_in),
        .rx_valid_in        (rx_valid_in),
        .warm_reset_pending (warm_reset_pending),
        .warm_reset_clear   (warm_reset_clear),
        .sw_in              (sw)
    );

    stream_accel_5x5_rgb #(.IMG_WIDTH(128)) my_conv (
        .clk      (clk),
        .reset    (reset),
        .switches (sw[3:0]),
        .we       (accel_we),
        .waddr    (dmem_write_address),
        .wdata    (dmem_write_data),
        .raddr    (dmem_read_address),
        .rdata    (accel_rdata)
    );

    dual_port_vram VRAM (
        .clk     (clk),
        .we_a    (vram_we),
        .wstrb_a (dmem_write_byte),
        .addr_a  (vram_write_addr),
        .din_a   (dmem_write_data),
        .addr_b  (vram_read_addr),
        .dout_b  (vga_pixel_rgb)
    );

    vga_controller VGA_CTRL (
        .clk_25MHz (clk),
        .reset     (reset),
        .hsync     (vga_hs),
        .vsync     (vga_vs),
        .video_on  (video_on),
        .x         (vga_x),
        .y         (vga_y),
        .h_count   (vga_h_count),
        .v_count   (vga_v_count)
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
    integer scan_result;
    integer image_file;
    integer vga_file;
    integer vram_pixel_count;
    integer sample_count;
    integer sample_idx;
    integer timeout_cycles;
    reg [7:0] input_image [0:INPUT_BYTES-1];
    reg [31:0] frame_buf [0:OUTPUT_PIXELS-1];
    reg capture_armed;
    reg capture_active;
    reg capture_done;
    reg [7:0] r8;
    reg [7:0] g8;
    reg [7:0] b8;

    task send_uart_byte_until_dmem_write;
        input [7:0] value;
        input [31:0] expected_addr;
        begin
            @(negedge clk);
            rx_data_in = value;
            rx_valid_in = 1'b1;

            wait (dmem_we_actual && dmem_write_address == expected_addr);

            rx_valid_in = 1'b0;
            @(negedge clk);
        end
    endtask

    always @(posedge clk) begin
        if (warm_reset_clear) begin
            warm_reset_pending <= 1'b0;
        end
    end

    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count > timeout_cycles) begin
            $display("FAIL: timeout waiting for VGA test to finish.");
            $finish;
        end

        if (reset && vram_we) begin
            vram_pixel_count <= vram_pixel_count + 1;

            if (vram_pixel_count == 0) begin
                $display("INFO: First VRAM write observed.");
            end else if ((vram_pixel_count % 2048) == 0) begin
                $display("INFO: VRAM write progress: %0d / %0d", vram_pixel_count, OUTPUT_PIXELS);
            end

            if (vram_pixel_count + 1 == OUTPUT_PIXELS) begin
                $display("INFO: VRAM received full %0d-pixel frame.", OUTPUT_PIXELS);
                capture_armed <= 1'b1;
            end
        end

        if (capture_armed && video_on && (vga_x == 0) && (vga_y == 0)) begin
            capture_armed  <= 1'b0;
            capture_active <= 1'b1;
            sample_count   <= 0;
            $display("INFO: Starting VGA frame capture at top-left visible pixel.");
        end

        if (capture_active && valid_draw_area && (vga_x[1:0] == 2'b00) && (vga_y[1:0] == 2'b00)) begin
            sample_idx = (vga_y >> 2) * OUT_IMG_WIDTH + (vga_x >> 2);
            if (sample_idx < OUTPUT_PIXELS) begin
                r8 = {vga_r, vga_r};
                g8 = {vga_g, vga_g};
                b8 = {vga_b, vga_b};
                frame_buf[sample_idx] <= {8'h00, r8, g8, b8};
                sample_count <= sample_count + 1;

                if (((sample_count + 1) % 2048) == 0) begin
                    $display("INFO: VGA capture progress: %0d / %0d pixels", sample_count + 1, OUTPUT_PIXELS);
                end

                if (sample_count + 1 == OUTPUT_PIXELS) begin
                    capture_active <= 1'b0;
                    capture_done <= 1'b1;
                    $display("PASS: VGA frame capture complete (%0d pixels).", OUTPUT_PIXELS);
                end
            end
        end
    end

    initial begin
        reset = 1'b0;
        sw = {1'b1, 11'b0, FILTER_MODE};
        rx_data_in = 8'h00;
        rx_valid_in = 1'b0;
        warm_reset_pending = 1'b0;
        cycle_count = 0;
        timeout_cycles = 150000000;
        vram_pixel_count = 0;
        sample_count = 0;
        sample_idx = 0;
        capture_armed = 1'b0;
        capture_active = 1'b0;
        capture_done = 1'b0;
        r8 = 8'h00;
        g8 = 8'h00;
        b8 = 8'h00;

        for (i = 0; i < OUTPUT_PIXELS; i = i + 1) begin
            frame_buf[i] = 32'h00000000;
        end

        image_file = $fopen("original_image1.txt", "r");
        if (image_file == 0) begin
            image_file = $fopen("original_image_rgb_bytes.txt", "r");
        end
        if (image_file == 0) begin
            $display("FAIL: could not open original_image1.txt or original_image_rgb_bytes.txt.");
            $finish;
        end

        for (i = 0; i < INPUT_BYTES; i = i + 1) begin
            scan_result = $fscanf(image_file, "%d\n", input_image[i]);
            if (scan_result != 1) begin
                $display("FAIL: could not read byte %0d from bootloader input file.", i);
                $finish;
            end
        end
        $fclose(image_file);

        $display("INFO: Loaded %0d bootloader input bytes.", INPUT_BYTES);

        repeat (10) @(negedge clk);
        reset = 1'b1;
        repeat (20) @(negedge clk);

        $display("INFO: Entering UART-load emulation phase.");
        for (i = 0; i < INPUT_BYTES; i = i + 1) begin
            send_uart_byte_until_dmem_write(input_image[i], (32'h00001000 + i));

            if ((i % 4096) == 0) begin
                $display("INFO: UART load progress: %0d / %0d bytes", i, INPUT_BYTES);
            end
        end

        repeat (10) @(negedge clk);
        sw[15] = 1'b0;
        $display("INFO: SW[15] is now low; processing should start.");

        wait (capture_done == 1'b1);

        vga_file = $fopen("vga_frame_pixels.txt", "w");
        if (vga_file == 0) begin
            $display("FAIL: could not open vga_frame_pixels.txt for writing.");
            $finish;
        end

        for (i = 0; i < OUTPUT_PIXELS; i = i + 1) begin
            $fdisplay(vga_file, "%08x", frame_buf[i]);
        end
        $fclose(vga_file);

        $display("PASS: Wrote VGA frame pixels to vga_frame_pixels.txt");
        $finish;
    end

endmodule
