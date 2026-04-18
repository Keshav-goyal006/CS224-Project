`timescale 1ns / 1ps

module top_fpga #(
    parameter IMEMSIZE = 65536, // Expanded to 64KB
    parameter DMEMSIZE = 65536  // Expanded to 64KB
)(
    input  wire clk,        // fast board clock (100 MHz)
    input  wire reset,      // active-low reset
    input  wire warm_reset_btn,
    input  wire [15:0] sw,
    output wire [15:0] led,
    
    // --- VGA PINS ---
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    output wire vga_hs,
    output wire vga_vs,

    output wire uart_txd,
    input  wire uart_rxd
);

    // -----------------------------------------------------------------
    // 100 MHz -> 25 MHz Clock Divider (Required for standard 640x480 VGA)
    // -----------------------------------------------------------------
    reg [1:0] clk_div;
    reg warm_reset_sync_1;
    reg warm_reset_sync_2;
    reg warm_reset_sync_3;
    reg warm_reset_pending;
    wire warm_reset_clear;
    always @(posedge clk or negedge reset) begin
        if (!reset) clk_div <= 2'b00;
        else clk_div <= clk_div + 1'b1;
    end
    wire clk_25MHz = clk_div[1]; 
    wire core_reset = reset & ~warm_reset_sync_2;

    always @(posedge clk_25MHz or negedge reset) begin
        if (!reset) begin
            warm_reset_sync_1 <= 1'b0;
            warm_reset_sync_2 <= 1'b0;
            warm_reset_sync_3 <= 1'b0;
            warm_reset_pending <= 1'b0;
        end else begin
            warm_reset_sync_1 <= warm_reset_btn;
            warm_reset_sync_2 <= warm_reset_sync_1;
            warm_reset_sync_3 <= warm_reset_sync_2;

            if (warm_reset_sync_2 && !warm_reset_sync_3) begin
                warm_reset_pending <= 1'b1;
            end else if (warm_reset_clear) begin
                warm_reset_pending <= 1'b0;
            end
        end
    end

    // -----------------------------------------------------------------
    // PIPE ↔ MEMORY WIRES
    // -----------------------------------------------------------------
    wire [31:0] pc_out_w;   
    wire exception;

    wire [31:0] inst_mem_read_data;
    wire [31:0] inst_mem_address;

    wire [31:0] dmem_read_data;
    wire        dmem_read_ready;
    wire [31:0] dmem_read_address;

    wire [31:0] cpu_rdata_mux;
    wire dmem_we_actual, accel_we, vram_we, uart_we, led_we, sim_trap_we;
    wire [31:0] accel_rdata;
    wire tx_active;
    wire [7:0] uart_byte;
    wire uart_done;

    wire [9:0] vga_x;
    wire [9:0] vga_y;
    wire [9:0] vga_h_count;
    wire [9:0] vga_v_count;
    wire video_on;
    wire [7:0] vga_pixel_data;
    
    wire        dmem_write_ready;
    wire [31:0] dmem_write_address;
    wire [31:0] dmem_write_data;
    wire [3:0]  dmem_write_byte;

    // -----------------------------------------------------------------
    // PIPELINE CPU (Running at 25 MHz)
    // -----------------------------------------------------------------
    pipe pipe_u (
        .clk                 (clk_25MHz),
        .reset               (core_reset),
        .stall               (1'b0),
        .exception           (exception),
        .pc_out              (pc_out_w),
        
        .inst_mem_is_valid   (1'b1),
        .inst_mem_read_data  (inst_mem_read_data),
        .inst_mem_address    (inst_mem_address),
        
        .dmem_read_valid     (1'b1),
        .dmem_read_data_temp (cpu_rdata_mux), // Connect to interconnect mux!
        .dmem_read_ready     (dmem_read_ready),
        .dmem_read_address   (dmem_read_address),
        
        .dmem_write_valid    (1'b1),
        .dmem_write_ready    (dmem_write_ready),
        .dmem_write_address  (dmem_write_address),
        .dmem_write_data     (dmem_write_data),
        .dmem_write_byte     (dmem_write_byte),
        .switch_in           (sw)
    );

    // -----------------------------------------------------------------
    // SOC INTERCONNECT & PERIPHERALS
    // -----------------------------------------------------------------
    uart_rx #(
        .CLOCKS_PER_BIT(217)
    ) uart_rx_inst (
        .clk(clk_25MHz),
        .rx(uart_rxd),
        .rx_data(uart_byte),
        .rx_done(uart_done)
    );

    // 1. The Interconnect (Traffic Cop)
    soc_interconnect bus (
        .clk        (clk_25MHz),          // New Clock Port
        .reset      (core_reset),              // New Reset Port
        
        .cpu_waddr  (dmem_write_address), // Separated Write Address
        .cpu_raddr  (dmem_read_address),  // Separated Read Address
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
        .vram_rdata (vga_pixel_data), 
        .accel_rdata(accel_rdata),
        .tx_active  (tx_active),
        .rx_data_in (uart_byte),
        .rx_valid_in(uart_done),
        .warm_reset_pending(warm_reset_pending),
        .warm_reset_clear(warm_reset_clear),
        .sw_in      (sw)
    );

    // LED Register Logic
    reg [15:0] led_reg;
    always @(posedge clk_25MHz or negedge core_reset) begin
        if (!core_reset) led_reg <= 16'b0;
        else if (led_we) led_reg <= dmem_write_data[15:0];
    end
    assign led = led_reg;

    // 2. Hardware Accelerator
    // conv_accelerator my_conv (
    //     .clk    (clk_25MHz),
    //     .reset  (reset),
    //     .we     (accel_we),
    //     .waddr  (dmem_write_address),
    //     .wdata  (dmem_write_data),
    //     .raddr  (dmem_read_address),
    //     .rdata  (accel_rdata)
    // );

    // 2. Hardware Accelerator
    // stream_accel #(.IMG_WIDTH(64)) my_conv (
    //     .clk      (clk_25MHz),
    //     .reset    (reset),
    //     .switches (sw[3:0]), // Pass the first 4 physical switches!
    //     .we       (accel_we),
    //     .waddr    (dmem_write_address),
    //     .wdata    (dmem_write_data),
    //     .raddr    (dmem_read_address),
    //     .rdata    (accel_rdata)
    // );

    stream_accel_9x9 #(.IMG_WIDTH(256)) my_conv (
        .clk      (clk_25MHz),         // Use the raw testbench clock
        .reset    (core_reset),
        .switches (sw[3:0]),
        .we       (accel_we),
        .waddr    (dmem_write_address),
        .wdata    (dmem_write_data),
        .raddr    (dmem_read_address),
        .rdata    (accel_rdata)
    );
    
    // 3. UART Transmitter
    // 3. UART Transmitter
    uart_tx #( .CLKS_PER_BIT(217) ) my_uart (
        .clk        (clk_25MHz), 
        .reset      (core_reset),
        .tx_start   (uart_we), 
        .tx_data    (dmem_write_data[7:0]),
        .tx_active  (tx_active),
        .tx_serial  (uart_txd) 
    );

    // 4. Base Memory
    instr_mem IMEM (
        .clk(clk_25MHz), 
        .pc(inst_mem_address), 
        .instr(inst_mem_read_data)
    );
    
    data_mem DMEM (
        .clk(clk_25MHz), 
        .re(dmem_read_ready), 
        .raddr(dmem_read_address), 
        .rdata(dmem_read_data), 
        .we(dmem_we_actual), // Protected by Interconnect
        .waddr(dmem_write_address), 
        .wdata(dmem_write_data), 
        .wstrb(dmem_write_byte)
    );

    // -----------------------------------------------------------------
    // VRAM AND VGA INTEGRATION
    // -----------------------------------------------------------------
    // Convert the 32-bit CPU address down to a 0-49151 index for 256x192 VRAM.
    wire [15:0] vram_write_addr = dmem_write_address[15:0];
    wire [15:0] vram_read_addr = ((vga_y >> 1) * 256) + (vga_x >> 1);
    
    // Instantiate Dual-Port VRAM
    dual_port_vram VRAM (
        .clk    (clk_25MHz),
        
        // Port A: CPU Write
        .we_a   (vram_we), // Now strictly controlled by the Interconnect!
        .addr_a (vram_write_addr),
        .din_a  (dmem_write_data[7:0]),
        
        // Port B: VGA Read
        // Scale 640x480 to 256x192 by dividing X and Y by 2.
        .addr_b (vram_read_addr),
        .dout_b (vga_pixel_data)
    );

    // Instantiate VGA Timing Controller
    vga_controller VGA_CTRL (
        .clk_25MHz (clk_25MHz),
        .reset     (reset),
        .hsync     (vga_hs),
        .vsync     (vga_vs),
        .video_on  (video_on),
        .x         (vga_x),
        .y         (vga_y),
        .h_count   (vga_h_count),
        .v_count   (vga_v_count)
    );

    // Map 8-bit grayscale VRAM data to 12-bit RGB Nexys A7 Output
    // If video_on is false, we MUST output black to keep the monitor synced
    // assign vga_r = video_on ? vga_pixel_data[7:4] : 4'h0;
    // assign vga_g = video_on ? vga_pixel_data[7:4] : 4'h0;
    // assign vga_b = video_on ? vga_pixel_data[7:4] : 4'h0;

    wire valid_draw_area = video_on && (vga_x < 512) && (vga_y < 384);

    assign vga_r = valid_draw_area ? vga_pixel_data[7:4] : 4'h0;
    assign vga_g = valid_draw_area ? vga_pixel_data[7:4] : 4'h0;
    assign vga_b = valid_draw_area ? vga_pixel_data[7:4] : 4'h0;

endmodule