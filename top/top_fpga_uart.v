`timescale 1ns / 1ps

module top_fpga (
    input  wire clk,        // Fast board clock (100 MHz)
    input  wire reset,      // Active-low reset
    output [15:0] led,
    output wire uart_txd    // <--- NEW: Physical pin to the USB chip
);

    wire [31:0] pc_out_w;   
    wire exception;
    wire [15:0] led_internal;
    // assign led = led_internal;

    // --- HARDWARE DIAGNOSTIC HIJACK ---
    // assign led = led_internal; 
    
    // LED 0 monitors the physical Reset Button
    assign led[0] = reset; 
    
    // LED 1 monitors the physical UART wire
    assign led[1] = uart_txd; 
    
    // Turn the rest off
    assign led[15:2] = 14'b0;

    // -----------------------------------------------------------------
    // CLOCK DIVIDER: 100MHz -> 50MHz
    // -----------------------------------------------------------------
    reg clk_50 = 1'b0;
    always @(posedge clk) begin
        clk_50 <= ~clk_50; // Flip the signal every clock tick
    end

    // -----------------------------------------------------------------
    // PIPE ↔ MEMORY WIRES
    // -----------------------------------------------------------------
    wire [31:0] inst_mem_read_data;
    wire [31:0] inst_mem_address;

    wire [31:0] dmem_read_data;
    wire        dmem_read_ready;
    wire [31:0] dmem_read_address;
    
    wire        dmem_write_ready;
    wire [31:0] dmem_write_address;
    wire [31:0] dmem_write_data;
    wire [3:0]  dmem_write_byte;

    // -----------------------------------------------------------------
    // PIPELINE CPU (Running at full 100 MHz)
    // -----------------------------------------------------------------
    pipe pipe_u (
        .clk                 (clk_50), // 100MHz
        .reset               (reset),
        .stall               (1'b0),
        .exception           (exception),
        .pc_out              (pc_out_w),
        
        .inst_mem_is_valid   (1'b1),
        .inst_mem_read_data  (inst_mem_read_data),
        .inst_mem_address    (inst_mem_address),
        
        .dmem_read_valid     (1'b1),
        .dmem_read_data_temp (dmem_read_data),
        .dmem_read_ready     (dmem_read_ready),
        .dmem_read_address   (dmem_read_address),
        
        .dmem_write_valid    (1'b1),
        .dmem_write_ready    (dmem_write_ready),
        .dmem_write_address  (dmem_write_address),
        .dmem_write_data     (dmem_write_data),
        .dmem_write_byte     (dmem_write_byte),

        .led_out             (led_internal),
        .uart_txd            (uart_txd) // Route UART out
    );

    instr_mem IMEM (.clk(clk), .pc(inst_mem_address), .instr(inst_mem_read_data));
    data_mem  DMEM (.clk(clk), .re(dmem_read_ready), .raddr(dmem_read_address), .rdata(dmem_read_data), .we(dmem_write_ready), .waddr(dmem_write_address), .wdata(dmem_write_data), .wstrb(dmem_write_byte));

endmodule