`timescale 1ns / 1ps

module soc_interconnect (
    input  wire        clk,    // NEW: Clock required for pipeline alignment
    input  wire        reset,  // NEW: Reset

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
    input  wire [31:0] uart_rdata
);

    // ==========================================
    // WRITE LOGIC (Combinational - 0 Cycle Delay)
    // ==========================================
    wire [19:0] wbase_addr = cpu_waddr[31:12];

    assign dmem_we     = (cpu_we && (wbase_addr == 20'h00001));
    assign accel_we    = (cpu_we && (wbase_addr == 20'h00002));
    assign led_we      = (cpu_we && (wbase_addr == 20'h00003));
    assign sim_trap_we = (cpu_we && (wbase_addr == 20'h00004));
    assign uart_we     = (cpu_we && (wbase_addr == 20'h00005));
    assign vram_we     = (cpu_we && (wbase_addr >= 20'h00010 && wbase_addr <= 20'h00014));

    // ==========================================
    // READ LOGIC (Sequential - 1 Cycle Delay Alignment)
    // ==========================================
    reg [19:0] rbase_addr_reg;
    reg [31:0] accel_rdata_reg;
    reg [31:0] uart_rdata_reg;
    reg [7:0]  vram_rdata_reg;

    // Shift data and addresses by 1 clock cycle to match DMEM latency
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            rbase_addr_reg  <= 20'h0;
            accel_rdata_reg <= 32'h0;
            uart_rdata_reg  <= 32'h0;
            vram_rdata_reg  <= 8'h0;
        end else begin
            rbase_addr_reg  <= cpu_raddr[31:12];
            accel_rdata_reg <= accel_rdata;
            uart_rdata_reg  <= uart_rdata;
            vram_rdata_reg  <= vram_rdata;
        end
    end

    // Multiplex the delayed data back to the CPU
    always @(*) begin
        // CRITICAL: We switch based on the 1-cycle old address (rbase_addr_reg)!
        case (rbase_addr_reg)
            20'h00001: cpu_rdata = dmem_rdata; // DMEM has its own internal 1-cycle delay
            20'h00002: cpu_rdata = accel_rdata_reg;
            20'h00005: cpu_rdata = uart_rdata_reg;
            default: begin
                if (rbase_addr_reg >= 20'h00010 && rbase_addr_reg <= 20'h00014)
                    cpu_rdata = {24'h000000, vram_rdata_reg}; 
                else
                    cpu_rdata = 32'h0000_0000;
            end
        endcase
    end
endmodule