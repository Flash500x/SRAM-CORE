## Arty A7-100 pins for the MicroBlaze + SRAM controller block design (design_1_wrapper)
## Port names match the external ports created in design_1 (sys_clock, reset, UART_0).

## 100 MHz oscillator
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports sys_clock]
## clock is created by clk_wiz_0, so not here: create_clock -name sys_clk -period 10.000 [get_ports sys_clock]

## RESET button (ck_rst), active low
set_property -dict { PACKAGE_PIN C2  IOSTANDARD LVCMOS33 } [get_ports reset]

## USB-UART: FPGA receives on A9, transmits on D10
set_property -dict { PACKAGE_PIN A9  IOSTANDARD LVCMOS33 } [get_ports UART_0_rxd]
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports UART_0_txd]

## Configuration
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
