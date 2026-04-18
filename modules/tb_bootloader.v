`timescale 1ns / 1ps

module tb_bootloader;

    reg clk;
    reg reset;
    reg [15:0] sw_in;
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
        .switch_in          (sw_in),
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
        .tx_active   (1'b0),
        .rx_data_in  (rx_data_in),
        .rx_valid_in (rx_valid_in),
        .warm_reset_pending(warm_reset_pending),
        .warm_reset_clear(warm_reset_clear),
        .sw_in       (sw_in)
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
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count > 200000) begin
            $display("FAIL: timeout waiting for bootloader test to finish.");
            $finish;
        end
    end

    always @(posedge clk) begin
        if (dmem_we_actual && dmem_write_address >= 32'h00001bf8) begin
            $display("DMEM WRITE: addr=%08x data=%08x wstrb=%b", dmem_write_address, dmem_write_data, dmem_write_byte);
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

    reg [7:0] expected_bytes [0:3071];
    integer i;
    integer word_index;
    reg [31:0] expected_word;

    initial begin
        reset = 1'b0;
        sw_in = 16'h8000;
        rx_data_in = 8'h00;
        rx_valid_in = 1'b0;
        warm_reset_pending = 1'b0;
        cycle_count = 0;

        repeat (10) @(negedge clk);
        reset = 1'b1;
        repeat (20) @(negedge clk);

        $display("Starting bootloader load test...");

        for (i = 0; i < 3072; i = i + 1) begin
            expected_bytes[i] = i & 8'hff;
            send_uart_byte(i & 8'hff);

            wait (dmem_we_actual && dmem_write_address == (32'h00001000 + i));
            @(negedge clk);
        end

        repeat (10) @(negedge clk);

        for (word_index = 0; word_index < 768; word_index = word_index + 1) begin
            expected_word = {
                expected_bytes[word_index * 4 + 3],
                expected_bytes[word_index * 4 + 2],
                expected_bytes[word_index * 4 + 1],
                expected_bytes[word_index * 4 + 0]
            };

            if (DMEM.dmem[word_index] !== expected_word) begin
                $display("FAIL: DMEM mismatch at word %0d. Got %08x expected %08x",
                    word_index, DMEM.dmem[word_index], expected_word);
                $finish;
            end
        end

        $display("Starting warm-reset check...\n");
        warm_reset_pending = 1'b1;
        reset = 1'b0;
        repeat (10) @(negedge clk);
        reset = 1'b1;
        repeat (20) @(negedge clk);

        for (word_index = 0; word_index < 768; word_index = word_index + 1) begin
            expected_word = {
                expected_bytes[word_index * 4 + 3],
                expected_bytes[word_index * 4 + 2],
                expected_bytes[word_index * 4 + 1],
                expected_bytes[word_index * 4 + 0]
            };

            if (DMEM.dmem[word_index] !== expected_word) begin
                $display("FAIL: Warm reset corrupted DMEM at word %0d. Got %08x expected %08x",
                    word_index, DMEM.dmem[word_index], expected_word);
                $finish;
            end
        end

        $display("PASS: Bootloader stored all 3072 bytes at 0x1000 correctly.");
        $display("PASS: Warm reset preserved the UART-loaded image in DMEM.");
        $finish;
    end

endmodule
