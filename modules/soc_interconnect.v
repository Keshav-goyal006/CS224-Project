`timescale 1ns / 1ps

module soc_interconnect (
    input  wire        clk,    
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
    
    // NEW: Split UART inputs
    input  wire        tx_active,
    input  wire [7:0]  rx_data_in,
    input  wire        rx_valid_in,

    input  wire [15:0] sw_in
);

    // ==========================================
    // WRITE LOGIC 
    // ==========================================
    wire [19:0] wbase_addr = cpu_waddr[31:12];
    assign dmem_we     = (cpu_we && (wbase_addr == 20'h00001));
    assign accel_we    = (cpu_we && (wbase_addr == 20'h00002));
    assign led_we      = (cpu_we && (wbase_addr == 20'h00003));
    assign sim_trap_we = (cpu_we && (wbase_addr == 20'h00004));
    assign uart_we     = (cpu_we && (wbase_addr == 20'h00005));
    assign vram_we     = (cpu_we && (wbase_addr >= 20'h00010 && wbase_addr <= 20'h00014));

    // ==========================================
    // THE RX READY TRAP (CATCH THE 1-CYCLE PULSE)
    // ==========================================
    reg rx_ready_reg;
    always @(posedge clk or negedge reset) begin
        if (!reset) 
            rx_ready_reg <= 1'b0;
        else if (rx_valid_in) 
            rx_ready_reg <= 1'b1; // Catch the pulse!
        else if (cpu_re && cpu_raddr[15:0] == 16'h5008) 
            rx_ready_reg <= 1'b0; // Clear ONLY when CPU reads the data
    end

    // ==========================================
    // READ LOGIC (Sequential)
    // ==========================================
    reg [19:0] rbase_addr_reg;
    reg [15:0] raddr_lower_reg; // NEED THIS to tell RX from TX!
    
    reg [31:0] accel_rdata_reg;
    reg [7:0]  vram_rdata_reg;
    reg [7:0]  rx_data_reg;
    reg        tx_active_reg;
    reg [15:0] sw_reg;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            rbase_addr_reg  <= 20'h0;
            raddr_lower_reg <= 16'h0;
            accel_rdata_reg <= 32'h0;
            vram_rdata_reg  <= 8'h0;
            rx_data_reg     <= 8'h0;
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
        end
    end

    always @(*) begin
        case (rbase_addr_reg)
            20'h00001: cpu_rdata = dmem_rdata;
            20'h00002: cpu_rdata = accel_rdata_reg;
            
            // THE NEW UART MULTIPLEXER
            20'h00005: begin
                if      (raddr_lower_reg == 16'h5004) cpu_rdata = {31'd0, tx_active_reg};
                else if (raddr_lower_reg == 16'h5008) cpu_rdata = {24'd0, rx_data_reg};
                else if (raddr_lower_reg == 16'h500C) cpu_rdata = {31'd0, rx_ready_reg};
                else    cpu_rdata = 32'd0;
            end

            20'h00006: cpu_rdata = {16'h0000, sw_reg}; // SW input at 0x00006000 - 0x00006FFF
            
            default: begin
                if (rbase_addr_reg >= 20'h00010 && rbase_addr_reg <= 20'h00014)
                    cpu_rdata = {24'h000000, vram_rdata_reg};
                else
                    cpu_rdata = 32'h0000_0000;
            end
        endcase
    end
endmodule