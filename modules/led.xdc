## -----------------------------------------------------------------
## Clock signal
## -----------------------------------------------------------------
# 100 MHz board clock
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }]; 
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];
## -----------------------------------------------------------------
## Reset
## -----------------------------------------------------------------
# Mapped to the CPU_RESETN button which is inherently active-low
set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { reset }];

##Switches
set_property IOSTANDARD LVCMOS33 [get_ports sw[*]];

set_property PACKAGE_PIN J15 [get_ports {sw[0]}];
set_property PACKAGE_PIN L16 [get_ports {sw[1]}];
set_property PACKAGE_PIN M13 [get_ports {sw[2]}];
set_property PACKAGE_PIN R15 [get_ports {sw[3]}];
set_property PACKAGE_PIN R17 [get_ports {sw[4]}];
set_property PACKAGE_PIN T18 [get_ports {sw[5]}];
set_property PACKAGE_PIN U18 [get_ports {sw[6]}];
set_property PACKAGE_PIN R13 [get_ports {sw[7]}];
set_property PACKAGE_PIN T8  [get_ports {sw[8]}];
set_property PACKAGE_PIN U8  [get_ports {sw[9]}];
set_property PACKAGE_PIN R16 [get_ports {sw[10]}];
set_property PACKAGE_PIN T13 [get_ports {sw[11]}];
set_property PACKAGE_PIN H6  [get_ports {sw[12]}];
set_property PACKAGE_PIN U12 [get_ports {sw[13]}];
set_property PACKAGE_PIN U11 [get_ports {sw[14]}];
set_property PACKAGE_PIN V10 [get_ports {sw[15]}];
## -----------------------------------------------------------------
## LEDs (16 total)
## -----------------------------------------------------------------
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { led[3] }];
set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { led[4] }];
set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports { led[5] }];
set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { led[6] }];
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports { led[7] }];
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { led[8] }];
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { led[9] }];
set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports { led[10] }];
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { led[11] }];
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { led[12] }];
set_property -dict { PACKAGE_PIN V14   IOSTANDARD LVCMOS33 } [get_ports { led[13] }];
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { led[14] }];
set_property -dict { PACKAGE_PIN V11   IOSTANDARD LVCMOS33 } [get_ports { led[15] }];


## -----------------------------------------------------------------
## USB-UART Interface
## -----------------------------------------------------------------
# FPGA Transmit (TX) -> PC Receive
set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { uart_txd }];

# FPGA Receive (RX) <- PC Transmit (ADDED FOR MEMORY LOADER)
set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { uart_rxd }];

## -----------------------------------------------------------------
## VGA Connector
## -----------------------------------------------------------------
# Red Signals
set_property -dict { PACKAGE_PIN A3    IOSTANDARD LVCMOS33 } [get_ports { vga_r[0] }];
set_property -dict { PACKAGE_PIN B4    IOSTANDARD LVCMOS33 } [get_ports { vga_r[1] }];
set_property -dict { PACKAGE_PIN C5    IOSTANDARD LVCMOS33 } [get_ports { vga_r[2] }];
set_property -dict { PACKAGE_PIN A4    IOSTANDARD LVCMOS33 } [get_ports { vga_r[3] }];

# Green Signals
set_property -dict { PACKAGE_PIN C6    IOSTANDARD LVCMOS33 } [get_ports { vga_g[0] }];
set_property -dict { PACKAGE_PIN A5    IOSTANDARD LVCMOS33 } [get_ports { vga_g[1] }];
set_property -dict { PACKAGE_PIN B6    IOSTANDARD LVCMOS33 } [get_ports { vga_g[2] }];
set_property -dict { PACKAGE_PIN A6    IOSTANDARD LVCMOS33 } [get_ports { vga_g[3] }];

# Blue Signals
set_property -dict { PACKAGE_PIN B7    IOSTANDARD LVCMOS33 } [get_ports { vga_b[0] }];
set_property -dict { PACKAGE_PIN C7    IOSTANDARD LVCMOS33 } [get_ports { vga_b[1] }];
set_property -dict { PACKAGE_PIN D7    IOSTANDARD LVCMOS33 } [get_ports { vga_b[2] }];
set_property -dict { PACKAGE_PIN D8    IOSTANDARD LVCMOS33 } [get_ports { vga_b[3] }];

# Sync Signals
set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { vga_hs }];
set_property -dict { PACKAGE_PIN B12   IOSTANDARD LVCMOS33 } [get_ports { vga_vs }];

set_property CFGBVS VCCO [current_design];
set_property CONFIG_VOLTAGE 3.3 [current_design];