module uart_rx #(
    parameter CLOCKS_PER_BIT = 868 // Defaults to 115200 baud @ 100MHz clock
)(
    input  wire       clk,
    input  wire       rx,       // Connect to FPGA RX pin
    output reg  [7:0] rx_data,  // The received byte
    output reg        rx_done   // Pulses high for 1 cycle when a byte is ready
);

    localparam s_IDLE      = 3'b000;
    localparam s_RX_START  = 3'b001;
    localparam s_RX_DATA   = 3'b010;
    localparam s_RX_STOP   = 3'b011;
    localparam s_CLEANUP   = 3'b100;

    reg [2:0]  state       = s_IDLE;
    reg [15:0] clock_count = 0;
    reg [2:0]  bit_index   = 0;
    
    // Double-register RX to prevent metastability
    reg rx_r1 = 1'b1;
    reg rx_r2 = 1'b1;
    always @(posedge clk) begin
        rx_r1 <= rx;
        rx_r2 <= rx_r1;
    end

    always @(posedge clk) begin
        case (state)
            s_IDLE: begin
                rx_done     <= 1'b0;
                clock_count <= 0;
                bit_index   <= 0;
                
                if (rx_r2 == 1'b0) // Start bit detected
                    state <= s_RX_START;
                else
                    state <= s_IDLE;
            end

            s_RX_START: begin
                if (clock_count == (CLOCKS_PER_BIT-1)/2) begin
                    if (rx_r2 == 1'b0) begin
                        clock_count <= 0;  // reset counter, found middle
                        state       <= s_RX_DATA;
                    end else begin
                        state       <= s_IDLE; // False alarm
                    end
                end else begin
                    clock_count <= clock_count + 1;
                    state       <= s_RX_START;
                end
            end

            s_RX_DATA: begin
                if (clock_count < CLOCKS_PER_BIT-1) begin
                    clock_count <= clock_count + 1;
                    state       <= s_RX_DATA;
                end else begin
                    clock_count          <= 0;
                    rx_data[bit_index]   <= rx_r2; // Sample bit
                    
                    if (bit_index < 7) begin
                        bit_index <= bit_index + 1;
                        state     <= s_RX_DATA;
                    end else begin
                        bit_index <= 0;
                        state     <= s_RX_STOP;
                    end
                end
            end

            s_RX_STOP: begin
                if (clock_count < CLOCKS_PER_BIT-1) begin
                    clock_count <= clock_count + 1;
                    state       <= s_RX_STOP;
                end else begin
                    rx_done     <= 1'b1; // Data is ready
                    clock_count <= 0;
                    state       <= s_CLEANUP;
                end
            end

            s_CLEANUP: begin
                rx_done <= 1'b0;
                state   <= s_IDLE;
            end

            default: state <= s_IDLE;
        endcase
    end
endmodule