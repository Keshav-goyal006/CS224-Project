`timescale 1ns / 1ps

module uart_tx #(
    // 100 MHz Clock / 115200 Baud Rate = 868 clocks per bit
    parameter CLKS_PER_BIT = 217
)(
    input       clk,
    input       reset,
    input       tx_start,   // Pulse high for 1 clock cycle to start sending
    input [7:0] tx_data,    // The 8-bit pixel data to send
    
    output reg  tx_active,  // High while sending (CPU must wait if this is high)
    output reg  tx_serial   // The physical wire going to the USB chip
);

    parameter IDLE         = 3'b000;
    parameter TX_START_BIT = 3'b001;
    parameter TX_DATA_BITS = 3'b010;
    parameter TX_STOP_BIT  = 3'b011;
    parameter CLEANUP      = 3'b100;
    
    reg [2:0] state;
    reg [9:0] clock_count;
    reg [2:0] bit_index;
    reg [7:0] saved_data;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            tx_serial <= 1'b1; // Idle state is high
            tx_active <= 1'b0;
            clock_count <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_serial   <= 1'b1;
                    tx_active   <= 1'b0;
                    clock_count <= 0;
                    bit_index   <= 0;
                    
                    if (tx_start) begin
                        tx_active  <= 1'b1;
                        saved_data <= tx_data;
                        state      <= TX_START_BIT;
                    end
                end
                
                // Send Start Bit (Drive line low)
                TX_START_BIT: begin
                    tx_serial <= 1'b0;
                    if (clock_count < CLKS_PER_BIT - 1) begin
                        clock_count <= clock_count + 1;
                    end else begin
                        clock_count <= 0;
                        state       <= TX_DATA_BITS;
                    end
                end
                
                // Send Data Bits (LSB first)
                TX_DATA_BITS: begin
                    tx_serial <= saved_data[bit_index];
                    if (clock_count < CLKS_PER_BIT - 1) begin
                        clock_count <= clock_count + 1;
                    end else begin
                        clock_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state     <= TX_STOP_BIT;
                        end
                    end
                end
                
                // Send Stop Bit (Drive line high)
                TX_STOP_BIT: begin
                    tx_serial <= 1'b1;
                    if (clock_count < CLKS_PER_BIT - 1) begin
                        clock_count <= clock_count + 1;
                    end else begin
                        clock_count <= 0;
                        state       <= CLEANUP;
                    end
                end
                
                // 1 clock cycle for the state machine to breathe
                CLEANUP: begin
                    tx_active <= 1'b0;
                    state     <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule