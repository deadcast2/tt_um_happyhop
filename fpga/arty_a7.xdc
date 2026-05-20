# Arty A7 35T constraints for the happyhop FPGA prototype.
# Digilent Pmod VGA on JB (upper) + JC (lower).
# Pin numbers come from the Arty A7 Rev. E master XDC.

# ============================================================================
# 100 MHz onboard oscillator -> sys_clk
# ============================================================================
set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports clk_100mhz]
create_clock -period 10.000 -name sys_clk [get_ports clk_100mhz]

# Tell Vivado about the derived pixel clock (= sys_clk / 4) so timing
# analysis sees it. The instance path matches the BUFG in arty_top.v.
create_generated_clock -name pixel_clk \
    -source [get_ports clk_100mhz] \
    -divide_by 4 \
    [get_pins pixel_clk_bufg/O]

# ============================================================================
# BTN0 = reset (active high)
# ============================================================================
set_property -dict { PACKAGE_PIN D9   IOSTANDARD LVCMOS33 } [get_ports btn0]
set_false_path -from [get_ports btn0]

# ============================================================================
# Digilent Pmod VGA on JB + JC
#   JB[1..4]  -> R[0..3]
#   JB[7..10] -> B[0..3]
#   JC[1..4]  -> G[0..3]
#   JC[7]     -> HSync
#   JC[8]     -> VSync
# ============================================================================

# Red on JB[1..4]
set_property -dict { PACKAGE_PIN E15  IOSTANDARD LVCMOS33 } [get_ports {vga_r[0]}]
set_property -dict { PACKAGE_PIN E16  IOSTANDARD LVCMOS33 } [get_ports {vga_r[1]}]
set_property -dict { PACKAGE_PIN D15  IOSTANDARD LVCMOS33 } [get_ports {vga_r[2]}]
set_property -dict { PACKAGE_PIN C15  IOSTANDARD LVCMOS33 } [get_ports {vga_r[3]}]

# Blue on JB[7..10]
set_property -dict { PACKAGE_PIN J17  IOSTANDARD LVCMOS33 } [get_ports {vga_b[0]}]
set_property -dict { PACKAGE_PIN J18  IOSTANDARD LVCMOS33 } [get_ports {vga_b[1]}]
set_property -dict { PACKAGE_PIN K15  IOSTANDARD LVCMOS33 } [get_ports {vga_b[2]}]
set_property -dict { PACKAGE_PIN J15  IOSTANDARD LVCMOS33 } [get_ports {vga_b[3]}]

# Green on JC[1..4]
set_property -dict { PACKAGE_PIN U12  IOSTANDARD LVCMOS33 } [get_ports {vga_g[0]}]
set_property -dict { PACKAGE_PIN V12  IOSTANDARD LVCMOS33 } [get_ports {vga_g[1]}]
set_property -dict { PACKAGE_PIN V10  IOSTANDARD LVCMOS33 } [get_ports {vga_g[2]}]
set_property -dict { PACKAGE_PIN V11  IOSTANDARD LVCMOS33 } [get_ports {vga_g[3]}]

# HSync on JC[7]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports vga_hs]
# VSync on JC[8]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports vga_vs]

# ============================================================================
# Bitstream config -- generate a .bin alongside the .bit; speed up by
# disabling unused pins
# ============================================================================
set_property CFGBVS         VCCO   [current_design]
set_property CONFIG_VOLTAGE 3.3    [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
