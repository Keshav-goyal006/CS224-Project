## Nexys A7 Master Constraints (subset for this design)

## 100 MHz onboard clock
set_property PACKAGE_PIN E3 [get_ports clk_100mhz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz]
create_clock -name sys_clk -period 10.000 [get_ports clk_100mhz]

## CPU reset button (active low)
set_property PACKAGE_PIN C12 [get_ports reset_n]
set_property IOSTANDARD LVCMOS33 [get_ports reset_n]

## VGA outputs
set_property PACKAGE_PIN A3 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN B4 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN C5 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN A4 [get_ports {vga_r[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[*]}]

set_property PACKAGE_PIN C6 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN A5 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN B6 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN A6 [get_ports {vga_g[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[*]}]

set_property PACKAGE_PIN B7 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN C7 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN D8 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN D7 [get_ports {vga_b[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[*]}]

set_property PACKAGE_PIN B11 [get_ports vga_hsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hsync]

set_property PACKAGE_PIN B12 [get_ports vga_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vsync]

## Switches used for filter selection
set_property PACKAGE_PIN J15 [get_ports {switches[0]}]
set_property PACKAGE_PIN L16 [get_ports {switches[1]}]
set_property PACKAGE_PIN M13 [get_ports {switches[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {switches[*]}]

## 16 user LEDs
set_property PACKAGE_PIN H17 [get_ports {led[0]}]
set_property PACKAGE_PIN K15 [get_ports {led[1]}]
set_property PACKAGE_PIN J13 [get_ports {led[2]}]
set_property PACKAGE_PIN N14 [get_ports {led[3]}]
set_property PACKAGE_PIN R18 [get_ports {led[4]}]
set_property PACKAGE_PIN V17 [get_ports {led[5]}]
set_property PACKAGE_PIN U17 [get_ports {led[6]}]
set_property PACKAGE_PIN U16 [get_ports {led[7]}]
set_property PACKAGE_PIN E19 [get_ports {led[8]}]
set_property PACKAGE_PIN U19 [get_ports {led[9]}]
set_property PACKAGE_PIN V19 [get_ports {led[10]}]
set_property PACKAGE_PIN W18 [get_ports {led[11]}]
set_property PACKAGE_PIN U15 [get_ports {led[12]}]
set_property PACKAGE_PIN U14 [get_ports {led[13]}]
set_property PACKAGE_PIN V14 [get_ports {led[14]}]
set_property PACKAGE_PIN V13 [get_ports {led[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]
