####---- CreateClock list ----
set BIT_SAMPLES 4
set BIT_PERIOD [expr 1000 / 12.0]
set CLK_PERIOD [expr $BIT_PERIOD / $BIT_SAMPLES]
set BYTE_PERIOD [expr $BIT_PERIOD * 8]

create_clock  -name {clk} -period [expr 1000 / 16.0] [get_ports {clk}] 
create_clock  -name {clk_usb} -period $CLK_PERIOD  [get_nets {clk_pll}] 
create_generated_clock  -name {clk_1mhz} -source [get_ports {clk}] [get_nets {clk_1mhz}] -divide_by 16
create_generated_clock  -name {clk_app} -source [get_ports {clk}] [get_nets {clk_2mhz}] -divide_by 8

set_clock_groups -asynchronous -group {clk} -group {clk_1mhz} -group {clk_app} -group {clk_usb}

set root_path "u_usb_cdc"
source ../../../../common/synplifypro/usb_cdc.sdc
