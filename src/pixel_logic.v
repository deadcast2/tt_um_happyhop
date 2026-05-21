// Per-pixel color: 16x16 smiley sprite (with blink + look-direction)
// scaled 2x within a 32x32 ball bbox.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module pixel_logic #(
    parameter [9:0] BALL_SIZE  = 10'd32,
    parameter [5:0] BG_COLOR   = 6'b000001,   // dark blue
    parameter [5:0] BALL_COLOR = 6'b111100    // yellow
)(
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [9:0] ball_x,    // top-left corner of the ball's bounding box
    input  wire [9:0] ball_y,
    input  wire       blink,         // when 1, swap eye rows for the closed-eye pattern
    input  wire       looking_right, // 1: eyes at cols 5-6 / 11-12  (looking right)
                                     // 0: eyes at cols 3-4 / 9-10   (looking left)
    output wire [5:0] rgb        // 2 bits per channel; RRGGBB
);

    // ---- Inside-ball check ------------------------------------------------
    wire in_ball =
        (x >= ball_x) && (x < ball_x + BALL_SIZE) &&
        (y >= ball_y) && (y < ball_y + BALL_SIZE);

    // ---- Sprite-relative coordinates --------------------------------------
    // dx, dy are valid (0..BALL_SIZE-1) only when in_ball is asserted.
    // Divide by 2 to map the 32-wide ball to the 16-wide sprite.
    wire [9:0] dx = x - ball_x;
    wire [9:0] dy = y - ball_y;
    wire [3:0] sprite_x = dx[4:1];
    wire [3:0] sprite_y = dy[4:1];

    // ---- 16x16 smiley sprite ROM ------------------------------------------
    // Each row is 16 bits, MSB = leftmost column.
    //
    //  Row | Visual           | Hex
    //   0  | ...XXXXXXXXXX... | 1FF8
    //   1  | ..XXXXXXXXXXXX.. | 3FFC
    //   2  | .XXXXXXXXXXXXXX. | 7FFE
    //   3  | XXXXXXXXXXXXXXXX | FFFF
    //   4  | XXX..XXXX..XXXXX | E79F   <-- eyes (1-px gaps at cols 3-4 and 9-10)
    //   5  | XXX..XXXX..XXXXX | E79F
    //   6  | XXXXXXXXXXXXXXXX | FFFF
    //   7  | XXXXXXXXXXXXXXXX | FFFF
    //   8  | XXXXXXXXXXXXXXXX | FFFF
    //   9  | XXX..........XXX | E00F   <-- mouth top (10 cols open)
    //  10  | XXXX........XXXX | F01F   <--          ( 8 cols open)
    //  11  | XXXXX......XXXXX | F83F   <-- mouth bottom (6 cols open)
    //  12  | XXXXXXXXXXXXXXXX | FFFF
    //  13  | .XXXXXXXXXXXXXX. | 7FFE
    //  14  | ..XXXXXXXXXXXX.. | 3FFC
    //  15  | ...XXXXXXXXXX... | 1FF8
    // Sprite rows 4 and 5 hold the eyes.
    //   0xE79F = 1110_0111_1001_1111 -> eyes at cols 3-4 and 9-10  (looking LEFT)
    //   0xF3CF = 1111_0011_1100_1111 -> eyes at cols 4-5 and 10-11 (looking RIGHT,
    //                                   shifted just one sprite column over so the
    //                                   direction change reads as subtle, not exaggerated)
    //   0xFFFF                       -> face fill (eyes closed; blink)
    function automatic [15:0] smiley_row(
        input [3:0] row,
        input       blink_in,
        input       look_right
    );
        case (row)
            4'd0:  smiley_row = 16'h1FF8;
            4'd1:  smiley_row = 16'h3FFC;
            4'd2:  smiley_row = 16'h7FFE;
            4'd3:  smiley_row = 16'hFFFF;
            4'd4:  smiley_row = blink_in ? 16'hFFFF : (look_right ? 16'hF3CF : 16'hE79F);
            4'd5:  smiley_row = blink_in ? 16'hFFFF : (look_right ? 16'hF3CF : 16'hE79F);
            4'd6:  smiley_row = 16'hFFFF;
            4'd7:  smiley_row = 16'hFFFF;
            4'd8:  smiley_row = 16'hFFFF;
            4'd9:  smiley_row = 16'hE00F;
            4'd10: smiley_row = 16'hF01F;
            4'd11: smiley_row = 16'hF83F;
            4'd12: smiley_row = 16'hFFFF;
            4'd13: smiley_row = 16'h7FFE;
            4'd14: smiley_row = 16'h3FFC;
            4'd15: smiley_row = 16'h1FF8;
            default: smiley_row = 16'h0000;
        endcase
    endfunction

    // Bit 15 = sprite column 0, bit 0 = sprite column 15.
    wire [15:0] sprite_bits = smiley_row(sprite_y, blink, looking_right);
    wire [3:0]  bit_index   = 4'd15 - sprite_x;
    wire        smiley_bit  = sprite_bits[bit_index];

    // Draw ball color only where both the bounding box and the sprite mask are set.
    wire face_pixel = in_ball && smiley_bit;
    assign rgb = face_pixel ? BALL_COLOR : BG_COLOR;

endmodule
