`timescale 1ns / 1ps

module stream_accel_9x9 #(
    parameter IMG_WIDTH = 256
)(
    input  wire clk,
    input  wire reset,
    input  wire [3:0] switches, // 4-bit switch input
    
    // CPU Interface
    input  wire        we,
    input  wire [31:0] waddr,
    input  wire [31:0] wdata,
    input  wire [31:0] raddr,
    output reg  [31:0] rdata
);

    // --------------------------------------------------------
    // 1. The 8 Line Buffers (Required for a 9-row window)
    // --------------------------------------------------------
    wire [7:0] lb_out [0:7];
    wire pixel_push = we && (waddr == 32'h00012024);

    // Cascade 8 line buffers together
    line_buffer #(.WIDTH(IMG_WIDTH)) LB1 (.clk(clk), .reset(reset), .en(pixel_push), .din(wdata[7:0]), .dout(lb_out[7]));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB2 (.clk(clk), .reset(reset), .en(pixel_push), .din(lb_out[7]),  .dout(lb_out[6]));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB3 (.clk(clk), .reset(reset), .en(pixel_push), .din(lb_out[6]),  .dout(lb_out[5]));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB4 (.clk(clk), .reset(reset), .en(pixel_push), .din(lb_out[5]),  .dout(lb_out[4]));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB5 (.clk(clk), .reset(reset), .en(pixel_push), .din(lb_out[4]),  .dout(lb_out[3]));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB6 (.clk(clk), .reset(reset), .en(pixel_push), .din(lb_out[3]),  .dout(lb_out[2]));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB7 (.clk(clk), .reset(reset), .en(pixel_push), .din(lb_out[2]),  .dout(lb_out[1]));
    line_buffer #(.WIDTH(IMG_WIDTH)) LB8 (.clk(clk), .reset(reset), .en(pixel_push), .din(lb_out[1]),  .dout(lb_out[0]));

    // --------------------------------------------------------
    // 2. The 9x9 Window Registers (81 Pixels)
    // --------------------------------------------------------
    reg signed [31:0] window [0:8][0:8];
    integer r, c;

    always @(posedge clk) begin
        if (!reset) begin
            for (r = 0; r < 9; r = r + 1) begin
                for (c = 0; c < 9; c = c + 1) begin
                    window[r][c] <= 0;
                end
            end
        end else if (pixel_push) begin
            // Shift all columns to the left
            for (r = 0; r < 9; r = r + 1) begin
                for (c = 0; c < 8; c = c + 1) begin
                    window[r][c] <= window[r][c+1];
                end
            end
            
            // Load the new right-most column from line buffers & input
            window[0][8] <= lb_out[0];
            window[1][8] <= lb_out[1];
            window[2][8] <= lb_out[2];
            window[3][8] <= lb_out[3];
            window[4][8] <= lb_out[4];
            window[5][8] <= lb_out[5];
            window[6][8] <= lb_out[6];
            window[7][8] <= lb_out[7];
            window[8][8] <= wdata[7:0]; // Newest live pixel at bottom right
        end
    end

    // --------------------------------------------------------
    // 3. Hardware Kernel ROM (Switch Controlled)
    // --------------------------------------------------------
    reg signed [31:0] weights [0:8][0:8];
    reg [4:0] shift_val;
    reg abs_val_enable;

    always @(*) begin
        // Default to 0 before applying switch logic
        for (r = 0; r < 9; r = r + 1) begin
            for (c = 0; c < 9; c = c + 1) begin
                weights[r][c] = 0;
            end
        end
        shift_val = 0;
        abs_val_enable = 0;

        case(switches)
            // --------------------------------------------------------
            // 1. HEAVY 9x9 BOX BLUR (Aggressive Smoothing)
            // --------------------------------------------------------
            4'b0001: begin 
                // Set every single pixel to 1 [cite: 101, 102]
                for (r = 0; r < 9; r = r + 1) begin
                    for (c = 0; c < 9; c = c + 1) begin
                        weights[r][c] = 1;
                    end
                end
                // Total sum is 81. Shift by 6 (divide by 64) for brightness, 
                // or 7 (divide by 128) for a darker, more averaged look[cite: 103, 104].
                shift_val = 6; 
                abs_val_enable = 0;
            end

            // --------------------------------------------------------
            // 2. 9x9 GAUSSIAN BLUR (Textbook Smooth Profile)
            // --------------------------------------------------------
            4'b0010: begin 
                // Rows 0 and 8
                weights[0][3]=1; weights[0][4]=2; weights[0][5]=1;
                weights[8][3]=1; weights[8][4]=2; weights[8][5]=1;
                // Rows 1 and 7
                weights[1][2]=1; weights[1][3]=4; weights[1][4]=8; weights[1][5]=4; weights[1][6]=1;
                weights[7][2]=1; weights[7][3]=4; weights[7][4]=8; weights[7][5]=4; weights[7][6]=1;
                // Rows 2 and 6
                weights[2][1]=1; weights[2][2]=8; weights[2][3]=16; weights[2][4]=32; weights[2][5]=16; weights[2][6]=8; weights[2][7]=1;
                weights[6][1]=1; weights[6][2]=8; weights[6][3]=16; weights[6][4]=32; weights[6][5]=16; weights[6][6]=8; weights[6][7]=1;
                // Rows 3 and 5
                weights[3][0]=1; weights[3][1]=4; weights[3][2]=16; weights[3][3]=32; weights[3][4]=64; weights[3][5]=32; weights[3][6]=16; weights[3][7]=4; weights[3][8]=1;
                weights[5][0]=1; weights[5][1]=4; weights[5][2]=16; weights[5][3]=32; weights[5][4]=64; weights[5][5]=32; weights[5][6]=16; weights[5][7]=4; weights[5][8]=1;
                // Row 4 (Center)
                weights[4][0]=2; weights[4][1]=8; weights[4][2]=32; weights[4][3]=64; weights[4][4]=128; weights[4][5]=64; weights[4][6]=32; weights[4][7]=8; weights[4][8]=2;
                
                // Sum is roughly 1024
                shift_val = 10; 
                abs_val_enable = 0;
            end

            // --------------------------------------------------------
            // 3. 9x9 LONG DIAGONAL MOTION BLUR
            // --------------------------------------------------------
            4'b0011: begin 
                // Creates a diagonal streak across the entire window
                for (r = 0; r < 9; r = r + 1) begin
                    weights[r][r] = 2; // Weights along the diagonal
                end
                // Sum is 18. Shift by 4 (divide by 16)
                shift_val = 4;
                abs_val_enable = 0;
            end

            // --------------------------------------------------------
            // 4. 9x9 HIGH-PASS SHARPEN
            // --------------------------------------------------------
            4'b0100: begin 
                // Set entire 9x9 to -1
                for (r = 0; r < 9; r = r + 1) begin
                    for (c = 0; c < 9; c = c + 1) begin
                        weights[r][c] = -1;
                    end
                end
                // Set the center to a very high value (80 + 1 to stay positive)
                weights[4][4] = 81; 
                shift_val = 0;
                abs_val_enable = 0;
            end

            // --------------------------------------------------------
            // NEW FILTER 1: 9x9 LARGE DISK BLUR (Radius 4.5)
            // Combination: 4'b1000 (Switch 4 Only)
            // --------------------------------------------------------
            4'b1000: begin 
                // Creates a circular averaging mask
                for (r = 0; r < 9; r = r + 1) begin
                    for (c = 0; c < 9; c = c + 1) begin
                        // Circle equation: (x-4)^2 + (y-4)^2 <= 16
                        if (((r-4)*(r-4) + (c-4)*(c-4)) <= 16)
                            weights[r][c] = 1;
                    end
                end
                shift_val = 6; // Sum is ~49 pixels; divide by 64
                abs_val_enable = 0;
            end

            // --------------------------------------------------------
            // NEW FILTER 2: 9x9 LAPLACIAN (Omnidirectional Edge)
            // Combination: 4'b0101 (Switches 1 & 3)
            // --------------------------------------------------------
            4'b0101: begin 
                // Highlights high-frequency edges by comparing center to surroundings
                for (r = 0; r < 9; r = r + 1) begin
                    for (c = 0; c < 9; c = c + 1) begin
                        weights[r][c] = -1;
                    end
                end
                weights[4][4] = 80; // Peak center relative to 80 neighbors
                shift_val = 0;
                abs_val_enable = 1; // Needs absolute value for visual edges [cite: 61]
            end

            // --------------------------------------------------------
            // NEW FILTER 3: 9x9 VERTICAL SOBEL (Edge Enhancement)
            // Combination: 4'b1010 (Switches 2 & 4)
            // --------------------------------------------------------
            4'b1010: begin 
                // Detects vertical changes in intensity (Gradients)
                for (r = 0; r < 9; r = r + 1) begin
                    weights[r][0] = -4; weights[r][1] = -3; weights[r][2] = -2; weights[r][3] = -1;
                    weights[r][5] =  1; weights[r][6] =  2; weights[r][7] =  3; weights[r][8] =  4;
                end
                shift_val = 0;
                abs_val_enable = 1; // Crucial for visualizing both left/right edges [cite: 61]
            end

            // --------------------------------------------------------
            // NEW FILTER 4: 9x9 DEEP 3D EMBOSS
            // Combination: 4'b0110 (Switches 2 & 3)
            // --------------------------------------------------------
            4'b0110: begin 
                // Gradients across the full window create a 3D shadow effect
                for (r = 0; r < 9; r = r + 1) begin
                    for (c = 0; c < 9; c = c + 1) begin
                        if (r + c < 8) weights[r][c] = -1; // Top-Left negative
                        else if (r + c > 8) weights[r][c] = 1; // Bottom-Right positive
                    end
                end
                weights[4][4] = 1; // Maintain center anchor
                shift_val = 0;
                abs_val_enable = 0; 
            end

            // --------------------------------------------------------
            // DEFAULT: IDENTITY (Pass-through) [cite: 105, 106]
            // --------------------------------------------------------
            default: begin 
                weights[4][4] = 1; 
                shift_val = 0;
                abs_val_enable = 0;
            end
        endcase
    end

    // --------------------------------------------------------
    // 4. THE 81-MULTIPLIER MATH ENGINE
    // --------------------------------------------------------
    reg signed [31:0] raw_mac;
    
    always @(*) begin
        raw_mac = 0;
        for (r = 0; r < 9; r = r + 1) begin
            for (c = 0; c < 9; c = c + 1) begin
                raw_mac = raw_mac + (window[r][c] * weights[r][c]);
            end
        end
    end

    // Apply Bit-Shift
    wire signed [31:0] shifted_mac = raw_mac >>> shift_val;

    // Apply Absolute Value
    wire signed [31:0] abs_mac = (abs_val_enable && shifted_mac < 0) ? -shifted_mac : shifted_mac;

    // Hardware Clamp (0-255)
    wire [31:0] final_pixel = (abs_mac < 0)   ? 32'd0 : 
                              (abs_mac > 255) ? 32'd255 : abs_mac;

    // --------------------------------------------------------
    // 5. CPU Read Interface (1-Cycle Pipeline Sync)
    // --------------------------------------------------------
    reg [31:0] final_pixel_reg;
    always @(posedge clk) begin
        if (!reset) final_pixel_reg <= 32'd0;
        else final_pixel_reg <= final_pixel;
    end

    always @(*) begin
        if (raddr == 32'h00012028) rdata = final_pixel_reg;
        else rdata = 32'h00000000;
    end

endmodule