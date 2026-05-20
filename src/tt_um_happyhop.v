/*
 * happyhop - Tiny Tapeout VGA bouncing-ball demo.
 *
 * Phase 3: the ball animates. Position registers update once per VSync;
 *          velocity components flip sign when the ball reaches a screen edge.
 *
 * Pinout (TT VGA PMOD, RGB222):
 *   uo[0]=R1   uo[1]=G1   uo[2]=B1   uo[3]=VSync
 *   uo[4]=R0   uo[5]=G0   uo[6]=B0   uo[7]=HSync
 *
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_happyhop (
    input  wire [7:0] ui_in,    // dedicated inputs  (unused for now)
    output wire [7:0] uo_out,   // dedicated outputs -> TT VGA PMOD
    input  wire [7:0] uio_in,   // bidir inputs  (unused)
    output wire [7:0] uio_out,  // bidir outputs (unused)
    output wire [7:0] uio_oe,   // bidir output-enable (all input)
    input  wire       ena,      // power-on enable (ignored - always 1 while powered)
    input  wire       clk,      // 25.175 MHz pixel clock from TT carrier board
    input  wire       rst_n     // active-low reset
);

    // ---- VGA sync generator ------------------------------------------------
    wire [9:0] pix_x;
    wire [9:0] pix_y;
    wire       hsync;
    wire       vsync;
    wire       video_active;

    vga_sync sync (
        .clk          (clk),
        .rst_n        (rst_n),
        .x            (pix_x),
        .y            (pix_y),
        .hsync        (hsync),
        .vsync        (vsync),
        .video_active (video_active)
    );

    // ---- Animation parameters ---------------------------------------------
    localparam [9:0]        SCREEN_W    = 10'd640;
    localparam [9:0]        SCREEN_H    = 10'd480;
    localparam [9:0]        BALL_SIZE_C = 10'd32;
    localparam [9:0]        INIT_BX     = 10'd304;   // centered horizontally
    localparam [9:0]        INIT_BY     = 10'd224;   // centered vertically
    localparam signed [3:0] INIT_VX     = 4'sd2;     // pixels per frame
    localparam signed [3:0] INIT_VY     = 4'sd1;

    // ---- Frame tick: falling edge of VSync (start of vertical sync pulse) -
    // This fires exactly once per 60 Hz frame.
    reg vsync_prev;
    always @(posedge clk) begin
        if (!rst_n) vsync_prev <= 1'b1;     // VSync idle is high
        else        vsync_prev <= vsync;
    end
    wire frame_tick = vsync_prev & ~vsync;

    // ---- Ball state --------------------------------------------------------
    reg [9:0]        ball_x_reg;
    reg [9:0]        ball_y_reg;
    reg signed [3:0] vel_x;
    reg signed [3:0] vel_y;

    // ---- Edge detection / next-position math (combinational) --------------
    // Sign-extend the 4-bit velocity to 11 bits so it can be added to a
    // 10-bit position with room for negative overshoot.
    wire signed [10:0] vel_x_ext = {{7{vel_x[3]}}, vel_x};
    wire signed [10:0] vel_y_ext = {{7{vel_y[3]}}, vel_y};

    // Provisional next position assuming velocity does not change.
    wire signed [10:0] next_x = $signed({1'b0, ball_x_reg}) + vel_x_ext;
    wire signed [10:0] next_y = $signed({1'b0, ball_y_reg}) + vel_y_ext;

    // Edge hit detection: would the next position put the ball off-screen?
    wire hit_left   = next_x < 0;
    wire hit_right  = (next_x + $signed({1'b0, BALL_SIZE_C})) > $signed({1'b0, SCREEN_W});
    wire hit_top    = next_y < 0;
    wire hit_bottom = (next_y + $signed({1'b0, BALL_SIZE_C})) > $signed({1'b0, SCREEN_H});

    // Apply edge bounce: flip velocity component on hit.
    wire signed [3:0] new_vel_x = (hit_left || hit_right) ? -vel_x : vel_x;
    wire signed [3:0] new_vel_y = (hit_top  || hit_bottom) ? -vel_y : vel_y;

    // Use the (possibly flipped) velocity to compute the actual position update,
    // so the ball never overshoots a wall.
    wire signed [10:0] new_vel_x_ext = {{7{new_vel_x[3]}}, new_vel_x};
    wire signed [10:0] new_vel_y_ext = {{7{new_vel_y[3]}}, new_vel_y};
    wire signed [10:0] applied_x     = $signed({1'b0, ball_x_reg}) + new_vel_x_ext;
    wire signed [10:0] applied_y     = $signed({1'b0, ball_y_reg}) + new_vel_y_ext;

    // ---- Ball state update (once per frame) -------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            ball_x_reg <= INIT_BX;
            ball_y_reg <= INIT_BY;
            vel_x      <= INIT_VX;
            vel_y      <= INIT_VY;
        end else if (frame_tick) begin
            ball_x_reg <= applied_x[9:0];
            ball_y_reg <= applied_y[9:0];
            vel_x      <= new_vel_x;
            vel_y      <= new_vel_y;
        end
    end

    // ---- Per-pixel color decision -----------------------------------------
    wire [5:0] rgb;
    pixel_logic pixels (
        .x      (pix_x),
        .y      (pix_y),
        .ball_x (ball_x_reg),
        .ball_y (ball_y_reg),
        .rgb    (rgb)
    );

    // Gate with video_active so RGB lines stay at 0 during blanking.
    wire [5:0] pixel = video_active ? rgb : 6'b000000;

    wire [1:0] R = pixel[5:4];
    wire [1:0] G = pixel[3:2];
    wire [1:0] B = pixel[1:0];

    // ---- Pack into TT VGA PMOD layout --------------------------------------
    assign uo_out[0] = R[1];
    assign uo_out[1] = G[1];
    assign uo_out[2] = B[1];
    assign uo_out[3] = vsync;
    assign uo_out[4] = R[0];
    assign uo_out[5] = G[0];
    assign uo_out[6] = B[0];
    assign uo_out[7] = hsync;

    // ---- Unused IO --------------------------------------------------------
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire _unused = &{ena, ui_in, uio_in, 1'b0};

endmodule
