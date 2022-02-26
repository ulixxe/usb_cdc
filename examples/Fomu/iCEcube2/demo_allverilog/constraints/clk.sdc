####---- CreateClock list ----
set BIT_SAMPLES 4
set BIT_PERIOD [expr 1000 / 12.0]
set CLK_PERIOD [expr $BIT_PERIOD / $BIT_SAMPLES]
set BYTE_PERIOD [expr $BIT_PERIOD * 8]

create_clock -name {clki} -period [expr 1000 / 48.0] [get_ports {clki}]
create_clock -name {clk_usb} -period [expr 1000 / 48.0] [get_nets {clk}]

# Somehow "create_generated_clock" confuses SynplifyPro and induces it to mess with global buffers.
#create_generated_clock  -name {clk_3mhz} -source [get_nets {clk}] [get_nets {clk_3mhz}] -divide_by 16
#create_generated_clock  -name {clk_app} -source [get_nets {clk}] [get_nets {clk_12mhz}] -divide_by 4
create_clock -name {clk_3mhz} -period [expr 1000 / 3.0] [get_nets {clk_3mhz}]
create_clock -name {clk_app} -period [expr 1000 / 12.0] [get_nets {clk_12mhz}]

set_clock_groups -asynchronous -group {clki} -group {clk_3mhz} -group {clk_app} -group {clk_usb}

set_false_path -to [get_ports {rgb* usb_dp_pu}]

set root_path "u_usb_cdc"
source ../../../../common/synplifypro/usb_cdc.sdc

set fid [open all_registers.txt w]
file_puts $fid "all_registers:" [all_registers]
close $fid
