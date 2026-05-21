# FPGA prototype (Arty A7 35T)

Plug a Digilent VGA PMOD into **JB** (R + B) + **JC** (G + HS + VS). Then
from the project root:

```sh
# Build (~45s)
'/c/AMDDesignTools/2025.2/Vivado/bin/vivado.bat' -mode batch -source fpga/build.tcl

# Flash to the connected Arty
'/c/AMDDesignTools/2025.2/Vivado/bin/vivado.bat' -mode batch -source fpga/flash.tcl
```

`arty_top.v` is FPGA-only: divides the 100 MHz oscillator to 25 MHz and
bit-replicates the chip's RGB222 → Digilent's RGB444. BTN0 resets. None of
these files go to silicon.
