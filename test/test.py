# SPDX-FileCopyrightText: 2026 happyhop authors
# SPDX-License-Identifier: Apache-2.0
"""
cocotb tests for the happyhop VGA sync timing.

640x480 @ 60 Hz spec (all counts are pixel clocks):
  Horizontal:  640 active + 16 front + 96 sync + 48 back   = 800 / line
  Vertical:    480 active + 10 front +  2 sync + 33 back   = 525 / frame

The simulation uses a 25 MHz clock for convenient round numbers; the real
chip will run at 25.175 MHz, but the cycle counts (which is what we assert
on) are identical.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


# Timing in pixel clocks
H_ACTIVE = 640
H_FRONT  = 16
H_SYNC   = 96
H_BACK   = 48
H_TOTAL  = H_ACTIVE + H_FRONT + H_SYNC + H_BACK   # 800

V_ACTIVE = 480
V_FRONT  = 10
V_SYNC   = 2
V_BACK   = 33
V_TOTAL  = V_ACTIVE + V_FRONT + V_SYNC + V_BACK   # 525

# TT VGA PMOD bit positions on uo_out
HSYNC_BIT = 7
VSYNC_BIT = 3


def hsync_of(dut) -> int:
    return (int(dut.uo_out.value) >> HSYNC_BIT) & 1


def vsync_of(dut) -> int:
    return (int(dut.uo_out.value) >> VSYNC_BIT) & 1


async def _reset_and_start_clock(dut):
    cocotb.start_soon(Clock(dut.clk, 40, unit="ns").start())  # 25 MHz
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    for _ in range(10):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1


@cocotb.test()
async def test_hsync_timing(dut):
    """HSync is active-low for 96 cycles in a line of 800 cycles."""
    await _reset_and_start_clock(dut)

    # Hunt for the next HSync falling edge.
    prev = hsync_of(dut)
    for _ in range(H_TOTAL * 2):
        await RisingEdge(dut.clk)
        cur = hsync_of(dut)
        if prev == 1 and cur == 0:
            break
        prev = cur
    else:
        assert False, "HSync never fell within two line periods"

    # Measure the low-pulse duration.
    low = 1
    while True:
        await RisingEdge(dut.clk)
        if hsync_of(dut) == 1:
            break
        low += 1
    assert low == H_SYNC, f"HSync low for {low} cycles, expected {H_SYNC}"

    # Measure the remainder of the line until the next falling edge.
    high = 1
    while True:
        await RisingEdge(dut.clk)
        if hsync_of(dut) == 0:
            break
        high += 1
    assert high == H_TOTAL - H_SYNC, (
        f"HSync high for {high} cycles, expected {H_TOTAL - H_SYNC}"
    )

    dut._log.info(f"HSync OK: low={low}, high={high}, period={low + high}")


@cocotb.test()
async def test_vsync_timing(dut):
    """VSync is active-low for 2 lines in a frame of 525 lines."""
    await _reset_and_start_clock(dut)

    # Hunt for the next VSync falling edge (may take up to one full frame).
    prev = vsync_of(dut)
    for _ in range(V_TOTAL * H_TOTAL * 2):
        await RisingEdge(dut.clk)
        cur = vsync_of(dut)
        if prev == 1 and cur == 0:
            break
        prev = cur
    else:
        assert False, "VSync never fell within two frame periods"

    low = 1
    while True:
        await RisingEdge(dut.clk)
        if vsync_of(dut) == 1:
            break
        low += 1
    expected_low = V_SYNC * H_TOTAL
    assert low == expected_low, (
        f"VSync low for {low} cycles, expected {expected_low}"
    )

    high = 1
    while True:
        await RisingEdge(dut.clk)
        if vsync_of(dut) == 0:
            break
        high += 1
    expected_high = (V_TOTAL - V_SYNC) * H_TOTAL
    assert high == expected_high, (
        f"VSync high for {high} cycles, expected {expected_high}"
    )

    dut._log.info(f"VSync OK: low={low}, high={high}, period={low + high}")


# ---- Phase 2: static ball ---------------------------------------------------

# Match the constants in tt_um_happyhop.v
BALL_X    = 304
BALL_Y    = 224
BALL_SIZE = 32

# RGB222 colors used in pixel_logic.v
BG_COLOR_RGB   = (0, 0, 1)   # dark blue
BALL_COLOR_RGB = (3, 3, 0)   # yellow
BLANK_RGB      = (0, 0, 0)


def rgb_from_uo(uo: int) -> tuple:
    """Decode a uo_out byte into a (R, G, B) tuple of 2-bit values."""
    # TT VGA PMOD: uo[0]=R1, uo[1]=G1, uo[2]=B1, uo[3]=VS,
    #              uo[4]=R0, uo[5]=G0, uo[6]=B0, uo[7]=HS
    r = (((uo >> 0) & 1) << 1) | ((uo >> 4) & 1)
    g = (((uo >> 1) & 1) << 1) | ((uo >> 5) & 1)
    b = (((uo >> 2) & 1) << 1) | ((uo >> 6) & 1)
    return (r, g, b)


async def sample_at(dut, target_x: int, target_y: int) -> int:
    """Advance the clock until the beam reaches (target_x, target_y); return uo_out."""
    # Cap the wait at two full frames so a bug can't hang the test forever.
    for _ in range(V_TOTAL * H_TOTAL * 2):
        await RisingEdge(dut.clk)
        x = int(dut.user_project.pix_x.value)
        y = int(dut.user_project.pix_y.value)
        if x == target_x and y == target_y:
            return int(dut.uo_out.value)
    raise AssertionError(f"Beam never reached ({target_x}, {target_y})")


@cocotb.test()
async def test_static_ball_centered(dut):
    """Dark-blue background with a yellow square ball centered on screen."""
    await _reset_and_start_clock(dut)

    # Inside the ball (its center)
    center = await sample_at(dut, BALL_X + BALL_SIZE // 2, BALL_Y + BALL_SIZE // 2)
    assert rgb_from_uo(center) == BALL_COLOR_RGB, (
        f"Ball center should be yellow, got {rgb_from_uo(center)}"
    )

    # Just outside the ball's left edge (still in active video)
    outside = await sample_at(dut, BALL_X - 1, BALL_Y + BALL_SIZE // 2)
    assert rgb_from_uo(outside) == BG_COLOR_RGB, (
        f"Just outside ball should be dark blue, got {rgb_from_uo(outside)}"
    )

    # Far from the ball - somewhere in the top-left corner
    corner = await sample_at(dut, 10, 10)
    assert rgb_from_uo(corner) == BG_COLOR_RGB, (
        f"Background should be dark blue, got {rgb_from_uo(corner)}"
    )

    # Outside the active region (in horizontal blanking) - color must be 0
    blank = await sample_at(dut, 700, 100)
    assert rgb_from_uo(blank) == BLANK_RGB, (
        f"Blanking pixel must be black, got {rgb_from_uo(blank)}"
    )

    dut._log.info("Static ball pixel sampling OK")


@cocotb.test()
async def test_ball_bounding_box(dut):
    """Pixels outside the 32x32 bounding box always render the background color,
    regardless of the sprite content inside."""
    await _reset_and_start_clock(dut)

    # One pixel past the right edge is outside the bbox.
    just_right = await sample_at(dut, BALL_X + BALL_SIZE, BALL_Y + BALL_SIZE // 2)
    assert rgb_from_uo(just_right) == BG_COLOR_RGB, (
        f"1 past right edge should be background, got {rgb_from_uo(just_right)}"
    )

    # One pixel past the bottom edge is outside the bbox.
    just_below = await sample_at(dut, BALL_X + BALL_SIZE // 2, BALL_Y + BALL_SIZE)
    assert rgb_from_uo(just_below) == BG_COLOR_RGB, (
        f"1 past bottom edge should be background, got {rgb_from_uo(just_below)}"
    )

    dut._log.info("Bounding-box exclusion OK")


# ---- Phase 3: ball motion ---------------------------------------------------

# Match the localparams in tt_um_happyhop.v
INIT_BX, INIT_BY = 304, 224
INIT_VX, INIT_VY = 2, 1


async def wait_for_frame_tick(dut) -> None:
    """Block until one frame has elapsed (VSync falling edge), then one more cycle
    so the ball-state always-block has applied the update."""
    prev = vsync_of(dut)
    for _ in range(V_TOTAL * H_TOTAL * 2):
        await RisingEdge(dut.clk)
        cur = vsync_of(dut)
        if prev == 1 and cur == 0:
            await RisingEdge(dut.clk)
            return
        prev = cur
    raise AssertionError("Frame tick never arrived")


def ball_xy(dut) -> tuple:
    return int(dut.user_project.ball_x_reg.value), int(dut.user_project.ball_y_reg.value)


@cocotb.test()
async def test_ball_motion(dut):
    """Ball moves by (vel_x, vel_y) each frame from the centered start position."""
    await _reset_and_start_clock(dut)

    # Right after reset, before any frame tick, ball is at initial position.
    bx0, by0 = ball_xy(dut)
    assert (bx0, by0) == (INIT_BX, INIT_BY), (
        f"Ball should start at ({INIT_BX}, {INIT_BY}), got ({bx0}, {by0})"
    )

    # After one frame tick, ball should have advanced by (vel_x, vel_y).
    await wait_for_frame_tick(dut)
    bx1, by1 = ball_xy(dut)
    assert (bx1, by1) == (INIT_BX + INIT_VX, INIT_BY + INIT_VY), (
        f"After 1 frame, expected ({INIT_BX + INIT_VX}, {INIT_BY + INIT_VY}), "
        f"got ({bx1}, {by1})"
    )

    # After a few more frames, position should keep advancing linearly.
    for n in range(2, 6):
        await wait_for_frame_tick(dut)
        bx, by = ball_xy(dut)
        assert (bx, by) == (INIT_BX + n * INIT_VX, INIT_BY + n * INIT_VY), (
            f"After {n} frames, expected "
            f"({INIT_BX + n * INIT_VX}, {INIT_BY + n * INIT_VY}), got ({bx}, {by})"
        )

    dut._log.info(f"Ball motion OK after 5 frames at ({bx}, {by})")


# ---- Phase 4: smiley face sprite -------------------------------------------
#
# The smiley sprite is 16x16, scaled 2x inside the 32x32 ball bounding box.
# At ball position (BALL_X, BALL_Y) = (304, 224), each sprite cell (sx, sy)
# occupies the 2x2 screen block at (BALL_X + 2*sx, BALL_Y + 2*sy).
#
# Sprite layout (1 = face, 0 = background):
#   Row 4-5  cols 3,4 and 9,10 are 0  -> eye holes
#   Row 9-11 cols 3..12 are 0 (varying)-> mouth cavity
#   Otherwise mostly 1                  -> face fill (with rounded corners)

# All samples below are within the first frame (y < 490) so the ball stays
# at the initial position. Samples are ordered by ascending y, then x, so
# the beam sweeps over them in a single raster pass.


def ball_screen_coords(sprite_x: int, sprite_y: int) -> tuple:
    """Top-left screen pixel of a sprite cell when ball is at initial position."""
    return INIT_BX + 2 * sprite_x, INIT_BY + 2 * sprite_y


@cocotb.test()
async def test_smiley_features(dut):
    """Eyes, mouth, and face fill render at the expected sprite positions."""
    await _reset_and_start_clock(dut)

    # Background well clear of the ball.
    bg = await sample_at(dut, 10, 10)
    assert rgb_from_uo(bg) == BG_COLOR_RGB, f"Background should be blue, got {rgb_from_uo(bg)}"

    # Left eye - sprite (3, 4) is 0 (hole). On screen at (310, 232).
    eye_x, eye_y = ball_screen_coords(3, 4)
    left_eye = await sample_at(dut, eye_x, eye_y)
    assert rgb_from_uo(left_eye) == BG_COLOR_RGB, (
        f"Left eye at ({eye_x}, {eye_y}) should be background, got {rgb_from_uo(left_eye)}"
    )

    # Between the eyes - sprite (6, 4) is 1 (face). On screen at (316, 232).
    nose_x, nose_y = ball_screen_coords(6, 4)
    between_eyes = await sample_at(dut, nose_x, nose_y)
    assert rgb_from_uo(between_eyes) == BALL_COLOR_RGB, (
        f"Between eyes at ({nose_x}, {nose_y}) should be yellow, got {rgb_from_uo(between_eyes)}"
    )

    # Mouth - sprite (8, 10) is 0 (cavity). On screen at (320, 244).
    mouth_x, mouth_y = ball_screen_coords(8, 10)
    mouth = await sample_at(dut, mouth_x, mouth_y)
    assert rgb_from_uo(mouth) == BG_COLOR_RGB, (
        f"Mouth at ({mouth_x}, {mouth_y}) should be background, got {rgb_from_uo(mouth)}"
    )

    # Chin - sprite (7, 14) is 1 (face). On screen at (318, 252).
    chin_x, chin_y = ball_screen_coords(7, 14)
    chin = await sample_at(dut, chin_x, chin_y)
    assert rgb_from_uo(chin) == BALL_COLOR_RGB, (
        f"Chin at ({chin_x}, {chin_y}) should be yellow, got {rgb_from_uo(chin)}"
    )

    dut._log.info("Smiley features verified (eyes, nose, mouth, chin)")


@cocotb.test()
async def test_smiley_rounded_corners(dut):
    """Corner sprite cells are 0 (transparent) so the face reads as round."""
    await _reset_and_start_clock(dut)

    # Sprite row 0 col 0 is 0 -> background even though pixel is inside bbox.
    tl_x, tl_y = ball_screen_coords(0, 0)
    tl = await sample_at(dut, tl_x, tl_y)
    assert rgb_from_uo(tl) == BG_COLOR_RGB, (
        f"Top-left corner of bbox at ({tl_x}, {tl_y}) should be background, got {rgb_from_uo(tl)}"
    )

    # Sprite (5, 0) is 1 (face top).
    top_x, top_y = ball_screen_coords(5, 0)
    top = await sample_at(dut, top_x, top_y)
    assert rgb_from_uo(top) == BALL_COLOR_RGB, (
        f"Top of face at ({top_x}, {top_y}) should be yellow, got {rgb_from_uo(top)}"
    )

    dut._log.info("Rounded-corner sprite cells OK")
