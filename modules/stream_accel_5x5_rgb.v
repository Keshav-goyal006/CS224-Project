`timescale 1ns / 1ps

module stream_accel_5x5_rgb #(
    parameter IMG_WIDTH = 128 // Scaled down for 64KB DMEM limit
)(
    input  wire clk,
    input  wire reset,
    input  wire [3:0] switches, 
    
    // CPU Interface
    input  wire        we,
    input  wire [31:0] waddr,
    input  wire [31:0] wdata,  // Format: {8'h00, R[7:0], G[7:0], B[7:0]}
    input  wire [31:0] raddr,
    output reg  [31:0] rdata
);

    wire pixel_push = we && (waddr == 32'h00012024);

    // --------------------------------------------------------
    // 1. Four 24-Bit Line Buffers (Storing R, G, B)
    // --------------------------------------------------------
    wire [23:0] lb_out [0:3];
    
    line_buffer_rgb #(.WIDTH(IMG_WIDTH), .DATA_WIDTH(24)) LB1 (.clk(clk), .reset(reset), .en(pixel_push), .din(wdata[23:0]), .dout(lb_out[3]));
    line_buffer_rgb #(.WIDTH(IMG_WIDTH), .DATA_WIDTH(24)) LB2 (.clk(clk), .reset(reset), .en(pixel_push), .din(lb_out[3]),   .dout(lb_out[2]));
    line_buffer_rgb #(.WIDTH(IMG_WIDTH), .DATA_WIDTH(24)) LB3 (.clk(clk), .reset(reset), .en(pixel_push), .din(lb_out[2]),   .dout(lb_out[1]));
    line_buffer_rgb #(.WIDTH(IMG_WIDTH), .DATA_WIDTH(24)) LB4 (.clk(clk), .reset(reset), .en(pixel_push), .din(lb_out[1]),   .dout(lb_out[0]));

    // --------------------------------------------------------
    // 2. The 5x5 Window Registers (25 Pixels x 24-bit)
    // --------------------------------------------------------
    reg [23:0] window [0:4][0:4];
    integer r, c;

    always @(posedge clk) begin
        if (!reset) begin
            for (r=0; r<5; r=r+1) 
                for (c=0; c<5; c=c+1) 
                    window[r][c] <= 24'd0;
        end else if (pixel_push) begin
            // Shift columns left
            for (r=0; r<5; r=r+1) begin
                window[r][0] <= window[r][1];
                window[r][1] <= window[r][2];
                window[r][2] <= window[r][3];
                window[r][3] <= window[r][4];
            end
            
            // Load new right-most column from line buffers and live input
            window[0][4] <= lb_out[0];
            window[1][4] <= lb_out[1];
            window[2][4] <= lb_out[2];
            window[3][4] <= lb_out[3];
            window[4][4] <= wdata[23:0]; // Bottom right is live pixel
        end
    end

    // --------------------------------------------------------
    // 3. Hardware Kernel ROM (5x5 Kernels)
    // --------------------------------------------------------
    reg signed [31:0] weights [0:4][0:4];
    reg [4:0] shift_val;
    reg abs_val_enable;

    // New variables for Morphological Math
    reg [7:0] morph_R, morph_G, morph_B;

    always @(*) begin
        // Default clear
        for (r=0; r<5; r=r+1) for (c=0; c<5; c=c+1) weights[r][c] = 0;
        shift_val = 0;
        abs_val_enable = 0;

        // Default Morph values (start with center pixel)
        morph_R = window[2][2][23:16];
        morph_G = window[2][2][15:8];
        morph_B = window[2][2][7:0];

        case(switches)
            4'b0001: begin // 5x5 GAUSSIAN BLUR
                weights[0][0]=1; weights[0][1]=4;  weights[0][2]=6;  weights[0][3]=4;  weights[0][4]=1;
                weights[1][0]=4; weights[1][1]=16; weights[1][2]=24; weights[1][3]=16; weights[1][4]=4;
                weights[2][0]=6; weights[2][1]=24; weights[2][2]=36; weights[2][3]=24; weights[2][4]=6;
                weights[3][0]=4; weights[3][1]=16; weights[3][2]=24; weights[3][3]=16; weights[3][4]=4;
                weights[4][0]=1; weights[4][1]=4;  weights[4][2]=6;  weights[4][3]=4;  weights[4][4]=1;
                shift_val = 8; // Divide by 256
            end
            4'b0010: begin // 5x5 EDGE DETECT (Omnidirectional)
                for (r=0; r<5; r=r+1) for (c=0; c<5; c=c+1) weights[r][c] = -1;
                weights[2][2] = 24; // Center
                abs_val_enable = 1; // Need absolute value for color gradients
            end
            4'b0100: begin // 5x5 SHARPEN
                weights[0][2]=-2;
                weights[1][1]=-2; weights[1][2]=-4; weights[1][3]=-2;
                weights[2][0]=-2; weights[2][1]=-4; weights[2][2]=48; weights[2][3]=-4; weights[2][4]=-2;
                weights[3][1]=-2; weights[3][2]=-4; weights[3][3]=-2;
                weights[4][2]=-2;
                shift_val = 4; // Divide by 16
            end
            4'b0011: begin // 5x5 DIAGONAL MOTION BLUR
                // Set the diagonal streak, everything else defaults to 0
                weights[0][0]= 1; 
                weights[1][1]= 2; 
                weights[2][2]= 2; 
                weights[3][3]= 2; 
                weights[4][4]= 1;
                
                // Sum is 8. Divide by 8.
                shift_val = 3; 
                abs_val_enable = 0;
            end
            4'b0101: begin // 5x5 UNSHARP MASK (High-Contrast Sharpen)
                // Set the entire 5x5 grid to -1 (25 pixels = -25)
                for (r=0; r<5; r=r+1) 
                    for (c=0; c<5; c=c+1) 
                        weights[r][c] = -1;
                
                // Set the center to a massive positive value
                weights[2][2] = 33; 
                
                // Sum is 8 (-24 from edges + 33 from center). Divide by 8.
                shift_val = 3; 
                abs_val_enable = 0;
            end
            4'b0110: begin // 5x5 VERTICAL SOBEL (Finds vertical edges)
                // Left side is deeply negative, Right side is deeply positive
                weights[0][0]=-1; weights[0][1]=-2; weights[0][2]=0; weights[0][3]=2; weights[0][4]=1;
                weights[1][0]=-2; weights[1][1]=-3; weights[1][2]=0; weights[1][3]=3; weights[1][4]=2;
                weights[2][0]=-3; weights[2][1]=-5; weights[2][2]=0; weights[2][3]=5; weights[2][4]=3;
                weights[3][0]=-2; weights[3][1]=-3; weights[3][2]=0; weights[3][3]=3; weights[3][4]=2;
                weights[4][0]=-1; weights[4][1]=-2; weights[4][2]=0; weights[4][3]=2; weights[4][4]=1;
                
                // Edges will be negative or positive depending on light-to-dark transition
                // Absolute value makes all edges pop as bright colors
                shift_val = 0; 
                abs_val_enable = 1; 
            end
            4'b0111: begin // 5x5 CROSS FLARE
                // Horizontal Axis
                weights[2][0]=1; weights[2][1]=2; weights[2][2]=4; weights[2][3]=2; weights[2][4]=1;
                // Vertical Axis (Overwriting the center)
                weights[0][2]=1; 
                weights[1][2]=2; 
                weights[2][2]=4; // Center overlap 
                weights[3][2]=2; 
                weights[4][2]=1;
                
                // Sum is 16. Divide by 16.
                shift_val = 4; 
                abs_val_enable = 0;
            end
            4'b1000: begin
                for (r=0; r<5; r=r+1) begin
                    for (c=0; c<5; c=c+1) begin
                        // If any neighbor is darker than our current min, update the min
                        if (window[r][c][23:16] < morph_R) morph_R = window[r][c][23:16];
                        if (window[r][c][15:8]  < morph_G) morph_G = window[r][c][15:8];
                        if (window[r][c][7:0]   < morph_B) morph_B = window[r][c][7:0];
                    end
                end
            end
            default: begin // IDENTITY (Pass-through)
                weights[2][2] = 1;
            end
        endcase
    end

    // --------------------------------------------------------
    // 4. THE 75-MULTIPLIER RGB MATH ENGINE
    // --------------------------------------------------------
    reg signed [31:0] mac_R, mac_G, mac_B;
    
    always @(*) begin
        mac_R = 0; mac_G = 0; mac_B = 0;
        for (r=0; r<5; r=r+1) begin
            for (c=0; c<5; c=c+1) begin
                // The 1'b0 prevents sign-extension of the 8-bit unsigned colors
                mac_R = mac_R + ($signed({1'b0, window[r][c][23:16]}) * weights[r][c]);
                mac_G = mac_G + ($signed({1'b0, window[r][c][15:8]})  * weights[r][c]);
                mac_B = mac_B + ($signed({1'b0, window[r][c][7:0]})   * weights[r][c]);
            end
        end
    end

    // Shift and Apply Absolute Value (if Edge Detection is active)
    wire signed [31:0] shift_R = mac_R >>> shift_val;
    wire signed [31:0] shift_G = mac_G >>> shift_val;
    wire signed [31:0] shift_B = mac_B >>> shift_val;

    wire signed [31:0] abs_R = (abs_val_enable && shift_R < 0) ? -shift_R : shift_R;
    wire signed [31:0] abs_G = (abs_val_enable && shift_G < 0) ? -shift_G : shift_G;
    wire signed [31:0] abs_B = (abs_val_enable && shift_B < 0) ? -shift_B : shift_B;

    // Hardware Clamp (0-255 per channel)
    wire [7:0] final_R = (abs_R < 0) ? 8'd0 : (abs_R > 255) ? 8'd255 : abs_R[7:0];
    wire [7:0] final_G = (abs_G < 0) ? 8'd0 : (abs_G > 255) ? 8'd255 : abs_G[7:0];
    wire [7:0] final_B = (abs_B < 0) ? 8'd0 : (abs_B > 255) ? 8'd255 : abs_B[7:0];

    // Decide which math engine to use based on the switches
    wire [7:0] out_R = (switches >= 4'b1000) ? morph_R : final_R;
    wire [7:0] out_G = (switches >= 4'b1000) ? morph_G : final_G;
    wire [7:0] out_B = (switches >= 4'b1000) ? morph_B : final_B;

    wire [31:0] final_pixel = {8'h00, out_R, out_G, out_B};

    // Recombine into 32-bit word
    // wire [31:0] final_pixel = {8'h00, final_R, final_G, final_B};

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