# FPGA prototype (Arty A7 35T)

These files exist solely to let you test the happyhop chip RTL on a real
FPGA before tape-out. They never go to silicon.

## What's in this directory

- `arty_top.v` - A thin top-level wrapper. Generates a 25 MHz pixel clock
  from the Arty's 100 MHz oscillator, synchronizes BTN0 into the chip's
  active-low reset, instantiates `tt_um_happyhop_deadcast2`, and bit-replicates the
  chip's RGB222 outputs into the RGB444 expected by the Digilent Pmod VGA.
- `arty_a7.xdc` - Pin assignments + timing constraints for the Arty A7
  Rev. E. Assumes the Digilent Pmod VGA is plugged into JB (red + blue)
  and JC (green + HSync + VSync). To use different PMODs, edit the
  pin numbers in this file.
- `build.tcl` - Vivado batch script that creates a project, synthesizes,
  implements, and writes a bitstream.
- `flash.tcl` - Vivado batch script that programs the bitstream onto a
  connected Arty over JTAG.

## Quick start

The current install of Vivado is at `C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat`
and is not on the Git Bash PATH by default. Either use the full path or open
"Vivado 2025.2 Tcl Shell" from the Start Menu.

```sh
# Git Bash / WSL / Linux (use the install path)
'/c/AMDDesignTools/2025.2/Vivado/bin/vivado.bat' -mode batch -source fpga/build.tcl
'/c/AMDDesignTools/2025.2/Vivado/bin/vivado.bat' -mode batch -source fpga/flash.tcl

# Or from PowerShell / cmd
& "C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat" -mode batch -source fpga/build.tcl
& "C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat" -mode batch -source fpga/flash.tcl
```

Build takes ~3-5 minutes on a modern laptop. After flashing you should see a
solid dark-blue screen on the monitor connected to the Pmod VGA. Press BTN0 to
reset.

After a successful flash you should see a solid dark-blue screen on the
monitor connected to the Pmod VGA. Press BTN0 to reset.

## How the hardware connects

```
+--------------+        +-----------------+        +-------------------+
| Arty A7 35T  |--JB--->| Digilent Pmod   |--DB15->| VGA monitor       |
| Artix-7 FPGA |--JC--->| VGA             |        | 640x480 @ 60 Hz   |
+--------------+        +-----------------+        +-------------------+
```

Pmod VGA pinout used:
- **JB** (upper Pmod connector on the VGA Pmod): `R0..R3` on pins 1-4,
  `B0..B3` on pins 7-10
- **JC** (lower Pmod connector): `G0..G3` on pins 1-4, `HSync` on pin 7,
  `VSync` on pin 8

The chip itself only outputs `RGB222` (2 bits per channel). The wrapper
expands each channel to 4 bits by replicating the 2 bits, e.g. `R[1:0] = 2'b10`
becomes `R[3:0] = 4'b1010`. The eventual ASIC will not have this wrapper
and will drive the TT VGA PMOD directly with 6 color bits.

## Differences vs. the ASIC

- The ASIC will run at 25.175 MHz exactly (sourced from TT's onboard PLL).
  The FPGA divides 100 MHz by 4, so 25.000 MHz - close enough that monitors
  lock fine, but be aware the FPGA pixel clock is 0.7% slow relative to the
  spec.
- The ASIC outputs only 6 color bits (RGB222). The FPGA wrapper bit-extends
  those to RGB444 to drive the Pmod VGA. The chip RTL itself is unchanged
  between FPGA and silicon.
- BTN0 reset only exists on the FPGA. The chip uses TT's standard async
  reset; the FPGA synchronizer ensures the button press is glitch-free
  before it reaches the chip RTL.

## Troubleshooting

- **Monitor reports "no signal"**: HSync or VSync wiring is broken, or
  the pixel clock isn't running. Check that BTN0 isn't stuck pressed
  (held low through synchronizer = chip in permanent reset).
- **Picture is the wrong color**: bit ordering between TT VGA PMOD and
  Digilent Pmod might be swapped in `arty_top.v`. Check `chip_R/G/B`
  derivations against the pinout comment in `tt_um_happyhop_deadcast2.v`.
- **Vivado complains "clock_100mhz not found"**: verify your XDC matches
  the port name in `arty_top.v` (`clk_100mhz`, not `clock_100mhz`).
