// Arty A7 35T wrapper: /4 clock divide (100->25 MHz), RGB222 -> RGB444
// bit-replication, BTN0 -> active-low rst_n synchronizer. FPGA-only.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module arty_top (
    input  wire        clk_100mhz,   // 100 MHz onboard oscillator (pin E3)
    input  wire        btn0,         // Reset button (pin D9, active high)

    // Digilent Pmod VGA on JB (R + B) and JC (G + HS + VS)
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hs,
    output wire        vga_vs
);

    // ---- 100 MHz -> 25 MHz pixel clock (divide by 4) ----------------------
    reg [1:0] div_counter = 2'b00;
    always @(posedge clk_100mhz) div_counter <= div_counter + 1'b1;

    wire pixel_clk;
    BUFG pixel_clk_bufg (
        .I(div_counter[1]),
        .O(pixel_clk)
    );

    // ---- Synchronize the reset button into pixel_clk ----------------------
    reg [1:0] rst_sync = 2'b00;
    always @(posedge pixel_clk) rst_sync <= {rst_sync[0], btn0};
    wire rst_n = ~rst_sync[1];

    // ---- Instantiate the chip RTL -----------------------------------------
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_happyhop_deadcast2 dut (
        .ui_in   (8'b0),
        .uo_out  (uo_out),
        .uio_in  (8'b0),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (1'b1),
        .clk     (pixel_clk),
        .rst_n   (rst_n)
    );

    // ---- Unpack TT VGA PMOD signal layout from uo_out ---------------------
    //   uo[0]=R1, uo[1]=G1, uo[2]=B1, uo[3]=VS,
    //   uo[4]=R0, uo[5]=G0, uo[6]=B0, uo[7]=HS
    wire [1:0] chip_R = {uo_out[0], uo_out[4]};
    wire [1:0] chip_G = {uo_out[1], uo_out[5]};
    wire [1:0] chip_B = {uo_out[2], uo_out[6]};

    // ---- RGB222 -> RGB444 by bit-replication for Digilent Pmod VGA --------
    assign vga_r  = {chip_R, chip_R};
    assign vga_g  = {chip_G, chip_G};
    assign vga_b  = {chip_B, chip_B};
    assign vga_hs = uo_out[7];
    assign vga_vs = uo_out[3];

    // Silence unused-signal lints (uio not wired to anything on FPGA)
    wire _unused_ok = &{uio_out, uio_oe, 1'b0};

endmodule
