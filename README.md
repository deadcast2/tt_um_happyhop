![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# happyhop

A bouncing colored object - eventually a smiley face - rendered live to VGA
by a single Tiny Tapeout tile. No framebuffer; every pixel is computed on
the fly as the beam scans the screen.

Targeting the **GF26a** Tiny Tapeout shuttle (GlobalFoundries gf180mcuD).

See [docs/info.md](docs/info.md) for a description of what the project does
and how to use it.

## Project layout

```
happyhop/
  src/                     # Chip RTL - goes to silicon
    tt_um_happyhop_deadcast2.v       # TT-standard top module
    vga_sync.v             # 640x480 @ 60 Hz sync generator
    config.json            # LibreLane build settings - don't edit
  test/                    # cocotb simulation
    tb.v
    test.py
    Makefile
    requirements.txt
  fpga/                    # FPGA prototype on Arty A7 - NOT for silicon
    arty_top.v             # Clock gen + RGB222 -> RGB444 wrapper (TBD)
    arty_a7.xdc            # Arty A7 pin and timing constraints (TBD)
  docs/info.md             # Datasheet rendered on the TT submissions page
  info.yaml                # TT project metadata
  .github/workflows/       # TT CI - simulation, FPGA, hardening, docs
```

## Phases

1. **Phase 1** - VGA sync + solid dark-blue background. Proves the toolchain
   end to end.
2. **Phase 2** - Static colored square layered on the background.
3. **Phase 3** - Animated bouncing square (velocity flips at screen edges).
4. **Phase 4** - Upgrade the square to a smiley face using a small sprite-mask
   ROM (circle + eyes + mouth).

## Running the simulation

Requires Icarus Verilog (`iverilog`) and Python 3 with cocotb installed:

```sh
cd test
pip install -r requirements.txt
make
```

The cocotb tests verify HSync and VSync timing match the 640x480 @ 60 Hz spec.

## Building for the Arty A7 FPGA

The `fpga/` directory contains a TCL-driven Vivado flow that builds and flashes
a bitstream without ever opening the Vivado GUI.

```sh
# Build the bitstream (~3-5 min)
vivado -mode batch -source fpga/build.tcl

# Plug in the Arty via USB and flash
vivado -mode batch -source fpga/flash.tcl
```

See [fpga/README.md](fpga/README.md) for the pin wiring, troubleshooting
tips, and ASIC-vs-FPGA differences.

## Submitting to Tiny Tapeout

The `.github/workflows/` directory contains the TT CI that runs simulation,
FPGA synthesis (sta-only on the FPGA flow), and ASIC hardening via LibreLane.
Once pushed to GitHub with Actions enabled, every push runs the full flow and
emits a hardened GDS plus a results page.

See https://tinytapeout.com for shuttle status and submission instructions.
