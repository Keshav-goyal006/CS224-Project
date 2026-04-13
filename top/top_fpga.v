`timescale 1ns / 1ps

module top_fpga #(
    parameter IMEMSIZE = 4096,
    parameter DMEMSIZE = 4096
)(
    input  wire clk,        // fast board clock (100 MHz)
    input  wire reset,      // active-low reset
    output [15:0] led,
    
    // --- NEW: VGA PINS ---
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    output wire vga_hs,
    output wire vga_vs
);

    wire [31:0] pc_out_w;   
    
    wire exception;
    wire [15:0] led_internal;
    assign led = led_internal;

    // -----------------------------------------------------------------
    // 100 MHz -> 25 MHz Clock Divider (Required for standard 640x480 VGA)
    // -----------------------------------------------------------------
    reg [1:0] clk_div;
    always @(posedge clk or negedge reset) begin
        if (!reset) clk_div <= 2'b00;
        else clk_div <= clk_div + 1'b1;
    end
    wire clk_25MHz = clk_div[1]; 

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
    // PIPELINE CPU (Running at 25 MHz)
    // -----------------------------------------------------------------
    pipe pipe_u (
        .clk                 (clk_25MHz),
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

        .led_out             (led_internal)
    );

    instr_mem IMEM (.clk(clk_25MHz), .pc(inst_mem_address), .instr(inst_mem_read_data));
    // data_mem  DMEM (.clk(clk_25MHz), .re(dmem_read_ready), .raddr(dmem_read_address), .rdata(dmem_read_data), .we(dmem_write_ready), .waddr(dmem_write_address), .wdata(dmem_write_data), .wstrb(dmem_write_byte));

    data_mem  DMEM (
        .clk(clk_25MHz), 
        // PROTECT DMEM: Only read/write if the address is in the 0x0000XXXX range
        .re(dmem_read_ready && (dmem_read_address[31:16] == 16'h0000)), 
        .raddr(dmem_read_address), 
        .rdata(dmem_read_data), 
        .we(dmem_write_ready && (dmem_write_address[31:16] == 16'h0000)), 
        .waddr(dmem_write_address), 
        .wdata(dmem_write_data), 
        .wstrb(dmem_write_byte)
    );
    // -----------------------------------------------------------------
    // VRAM AND VGA INTEGRATION
    // -----------------------------------------------------------------
    // If the CPU writes to 0x4000XXXX, map it to VRAM instead of DMEM.
    wire is_vram_write = (dmem_write_ready && dmem_write_address[31:16] == 16'h4000);
    
    wire [9:0] vga_x;
    wire [9:0] vga_y;
    wire video_on;
    wire [7:0] vga_pixel_data;

    // Instantiate Dual-Port VRAM
    dual_port_vram VRAM (
        .clk(clk_25MHz),
        
        // Port A: CPU Write
        .we_a   (is_vram_write),
        .addr_a (dmem_write_address[14:0]), // CPU provides linear pixel index
        .din_a  (dmem_write_data[7:0]),     // Write lower 8 bits (grayscale)
        
        // Port B: VGA Read
        // Scale 640x480 to 160x120 by dividing X and Y by 4 (bit shifting by 2)
        .addr_b ( ((vga_y >> 2) * 160) + (vga_x >> 2) ),
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
        .y         (vga_y)
    );

    // Map 8-bit grayscale VRAM data to 12-bit RGB Nexys A7 Output
    // If video_on is false, we MUST output black to keep the monitor synced
    assign vga_r = video_on ? vga_pixel_data[7:4] : 4'h0;
    assign vga_g = video_on ? vga_pixel_data[7:4] : 4'h0;
    assign vga_b = video_on ? vga_pixel_data[7:4] : 4'h0;

endmodule