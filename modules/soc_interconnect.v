`timescale 1ns / 1ps

module soc_interconnect (
    // CPU Interface
    input  wire [31:0] cpu_waddr,  // Address used for writes
    input  wire [31:0] cpu_raddr,  // Address used for reads
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

    // Decode logic for WRITES based on cpu_waddr
    wire [19:0] wbase_addr = cpu_waddr[31:12];

    assign dmem_we     = (cpu_we && (wbase_addr == 20'h00001));
    assign accel_we    = (cpu_we && (wbase_addr == 20'h00002));
    assign led_we      = (cpu_we && (wbase_addr == 20'h00003));
    assign sim_trap_we = (cpu_we && (wbase_addr == 20'h00004));
    assign uart_we     = (cpu_we && (wbase_addr == 20'h00005));
    assign vram_we     = (cpu_we && (wbase_addr >= 20'h00010 && wbase_addr <= 20'h00014));

    // Decode logic for READS based on cpu_raddr
    wire [19:0] rbase_addr = cpu_raddr[31:12];

    // always @(*) begin
    //     cpu_rdata = 32'h0000_0000;
        
    //     if (cpu_re) begin
    //         case (rbase_addr)
    //             20'h00001: cpu_rdata = dmem_rdata;
    //             20'h00002: cpu_rdata = accel_rdata;
    //             20'h00005: cpu_rdata = uart_rdata;
    //             default: begin
    //                 if (rbase_addr >= 20'h00010 && rbase_addr <= 20'h00014)
    //                     cpu_rdata = {24'h000000, vram_rdata}; // Zero-extend 8-bit pixel
    //                 else
    //                     cpu_rdata = 32'hDEAD_BEEF; // Error state
    //             end
    //         endcase
    //     end
    // end

    // Read Data Multiplexer (BULLETPROOF VERSION)
    always @(*) begin
        cpu_rdata = 32'h0000_0000; // Default to zero for unmapped addresses
        // Ignore cpu_re. If the CPU provides an address, instantly give it the data!
        case (rbase_addr)
            20'h00001: cpu_rdata = dmem_rdata;
            20'h00002: cpu_rdata = accel_rdata;
            20'h00005: cpu_rdata = uart_rdata;
            default: begin
                if (rbase_addr >= 20'h00010 && rbase_addr <= 20'h00014)
                    cpu_rdata = {24'h000000, vram_rdata}; 
                else
                    cpu_rdata = 32'h0000_0000; 
            end
        endcase
    end
endmodule