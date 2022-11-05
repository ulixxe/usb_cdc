####---- CreateClock list ----
set BIT_SAMPLES 4
set BIT_PERIOD [expr 1000 / 12.0]
set CLK_PERIOD [expr $BIT_PERIOD / $BIT_SAMPLES]
set BYTE_PERIOD [expr $BIT_PERIOD * 8]

create_clock -name {clk} -period [expr 1000 / 16.0] [get_ports {clk}]
create_clock -name {clk_usb} -period $CLK_PERIOD [get_nets {clk_pll}]

set_clock_groups -asynchronous -group {clk} -group {clk_usb}

set_false_path -to [get_ports {led usb_pu}]

set root_path "u_usb_cdc"
source ../../../../common/synplifypro/usb_cdc.sdc

set fid [open all_registers.txt w]
file_puts $fid "all_registers:" [all_registers]
close $fid
