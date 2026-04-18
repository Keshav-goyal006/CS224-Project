`timescale 1ns / 1ps

module soc_interconnect (
    input  wire        clk,    // Clock required for pipeline alignment
    input  wire        reset,  

    // CPU Interface
    input  wire [31:0] cpu_waddr,  
    input  wire [31:0] cpu_raddr,  
    input  wire [31:0] cpu_wdata,
    input  wire        cpu_we,     
    input  wire        cpu_re,     
    output reg  [31:0] cpu_rdata,  

    // Peripheral Write Enables
    output wire        dmem_we,
    output wire        vram_we,
    output wire        accel_we,
    output wire        led_we,
    output wire        uart_we,
    output wire        sim_trap_we,

    // Peripheral Read Data
    input  wire [31:0] dmem_rdata,
    input  wire [7:0]  vram_rdata,  
    input  wire [31:0] accel_rdata,
    input  wire        tx_active,
    input  wire [7:0]  rx_data_in,
    input  wire        rx_valid_in,
    input  wire        warm_reset_pending,
    output wire        warm_reset_clear,

    input  wire [15:0] sw_in
);

    // ==========================================
    // WRITE LOGIC (Combinational - 0 Cycle Delay)
    // ==========================================
    wire [19:0] wbase_addr = cpu_waddr[31:12];

    // 1. DMEM owns the entire bottom 64KB (0x0000_0000 to 0x0000_FFFF)
    assign dmem_we     = (cpu_we && (cpu_waddr < 32'h0001_0000));
    
    // 2. MMIO Peripherals safely pushed above the 64KB boundary
    assign accel_we    = (cpu_we && (wbase_addr == 20'h00012)); // 0x0001_2000
    assign led_we      = (cpu_we && (wbase_addr == 20'h00013)); // 0x0001_3000
    assign sim_trap_we = (cpu_we && (wbase_addr == 20'h00014)); // 0x0001_4000
    assign uart_we     = (cpu_we && (wbase_addr == 20'h00015)); // 0x0001_5000
    assign warm_reset_clear = (cpu_we && (wbase_addr == 20'h00016) && cpu_waddr[15:0] == 16'h6014);

    // 3. VRAM gets a massive 64KB chunk to hold the 256x192 output image
    // Covers 0x0003_0000 to 0x0003_FFFF
    assign vram_we     = (cpu_we && (wbase_addr >= 20'h00030 && wbase_addr <= 20'h0003F));

    // ==========================================
    // READ LOGIC (Sequential - 1 Cycle Delay Alignment)
    // ==========================================
    reg [19:0] rbase_addr_reg;
    reg [15:0] raddr_lower_reg;
    reg [31:0] accel_rdata_reg;
    reg [7:0]  vram_rdata_reg;
    reg [7:0]  rx_data_reg;
    reg        rx_ready_reg;
    reg        tx_active_reg;
    reg [15:0] sw_reg;

    // Shift data and addresses by 1 clock cycle to match DMEM latency
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            rbase_addr_reg  <= 20'h0;
            raddr_lower_reg <= 16'h0;
            accel_rdata_reg <= 32'h0;
            vram_rdata_reg  <= 8'h0;
            rx_data_reg     <= 8'h0;
            rx_ready_reg    <= 1'b0;
            tx_active_reg   <= 1'b0;
            sw_reg          <= 16'h0;
        end else begin
            rbase_addr_reg  <= cpu_raddr[31:12];
            raddr_lower_reg <= cpu_raddr[15:0];
            accel_rdata_reg <= accel_rdata;
            vram_rdata_reg  <= vram_rdata;
            rx_data_reg     <= rx_data_in;
            tx_active_reg   <= tx_active;
            sw_reg          <= sw_in;

            if (rx_valid_in) begin
                rx_ready_reg <= 1'b1;
            end else if (cpu_re && (cpu_raddr[31:12] == 20'h00015) && (cpu_raddr[15:0] == 16'h5008)) begin
                // Clear only when CPU consumes RX data.
                rx_ready_reg <= 1'b0;
            end
        end
    end

    // Multiplex the delayed data back to the CPU
    always @(*) begin
        // If the 1-cycle old address was in the bottom 64KB, return DMEM data
        if (rbase_addr_reg < 20'h00010) begin
            cpu_rdata = dmem_rdata;
        end else begin
            case (rbase_addr_reg)
                20'h00012: cpu_rdata = accel_rdata_reg;
                20'h00015: begin
                    if      (raddr_lower_reg == 16'h5004) cpu_rdata = {31'd0, tx_active_reg};
                    else if (raddr_lower_reg == 16'h5008) cpu_rdata = {24'd0, rx_data_reg};
                    else if (raddr_lower_reg == 16'h500C) cpu_rdata = {31'd0, rx_ready_reg};
                    else cpu_rdata = 32'd0;
                end
                20'h00016: begin
                    if      (raddr_lower_reg == 16'h6000) cpu_rdata = {16'd0, sw_reg};
                    else if (raddr_lower_reg == 16'h6010) cpu_rdata = {31'd0, warm_reset_pending};
                    else if (raddr_lower_reg == 16'h6014) cpu_rdata = 32'd0;
                    else cpu_rdata = 32'd0;
                end
                default: begin
                    // If in the VRAM range (0x0003_0000 to 0x0003_FFFF)
                    if (rbase_addr_reg >= 20'h00030 && rbase_addr_reg <= 20'h0003F)
                        cpu_rdata = {24'h000000, vram_rdata_reg}; 
                    else
                        cpu_rdata = 32'h0000_0000;
                end
            endcase
        end
    end
endmodule