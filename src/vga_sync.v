// 640x480 @ 60 Hz VGA sync generator, 25.175 MHz pixel clock.
//   H: 640 active + 16 fp + 96 sync + 48 bp = 800
//   V: 480 active + 10 fp +  2 sync + 33 bp = 525
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module vga_sync (
    input  wire        clk,           // 25.175 MHz pixel clock
    input  wire        rst_n,         // active-low reset
    output reg  [9:0]  x,             // current pixel column 0..799
    output reg  [9:0]  y,             // current line         0..524
    output wire        hsync,         // active low
    output wire        vsync,         // active low
    output wire        video_active   // 1 while the beam is inside 640x480 active region
);

    // ---- Horizontal counter ------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            x <= 10'd0;
        end else if (x == 10'd799) begin
            x <= 10'd0;
        end else begin
            x <= x + 10'd1;
        end
    end

    // ---- Vertical counter (advances at end-of-line) ------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            y <= 10'd0;
        end else if (x == 10'd799) begin
            if (y == 10'd524)
                y <= 10'd0;
            else
                y <= y + 10'd1;
        end
    end

    // ---- Sync pulses (active low per VGA spec) -----------------------------
    assign hsync = ~((x >= 10'd656) && (x <= 10'd751));
    assign vsync = ~((y >= 10'd490) && (y <= 10'd491));

    // ---- Active video region ----------------------------------------------
    // Color outputs MUST be zero outside this region or the monitor will
    // refuse to lock.
    assign video_active = (x < 10'd640) && (y < 10'd480);

endmodule
