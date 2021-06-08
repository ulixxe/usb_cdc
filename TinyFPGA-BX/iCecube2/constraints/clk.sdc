####---- CreateClock list ----
set BIT_SAMPLES 4
set BIT_PERIOD [expr 1000 / 12]
set CLK_PERIOD [expr $BIT_PERIOD / $BIT_SAMPLES]
set BYTE_PERIOD [expr $BIT_PERIOD * 8]

create_clock  -name {clk} -period [expr 1000 / 16] [get_ports {clk}] 
create_clock  -name {clk_pll} -period $CLK_PERIOD  [get_nets {clk_pll}] 
create_generated_clock  -name {clk_1mhz} -source [get_ports {clk}] [get_nets {clk_1mhz}] -divide_by 16
create_generated_clock  -name {app_clk} -source [get_ports {clk}] [get_nets {clk_2mhz}] -divide_by 8

set_clock_groups -asynchronous -group {clk} -group {clk_1mhz} -group {app_clk} -group {clk_pll}

#set_multicycle_path -setup 4 -to [remove_from_collection [all_registers] [get_cells "clk_cnt_q*"]]
#set_multicycle_path -hold 3 -to [remove_from_collection [all_registers] [get_cells "clk_cnt_q*"]]

set gated_cells [remove_from_collection -intersect [all_registers] [get_cells "u_usb_cdc.u_sie.u_phy_tx.tx_state_q* u_usb_cdc.u_sie.u_phy_tx.bit_cnt_q* u_usb_cdc.u_sie.u_phy_tx.data_q* u_usb_cdc.u_sie.u_phy_tx.stuffing_cnt_q* u_usb_cdc.u_sie.u_phy_tx.nrzi_q* u_usb_cdc.u_sie.u_phy_tx.tx_valid_q*"]]
set_multicycle_path -setup 8 -from $gated_cells
set_multicycle_path -hold 7 -from $gated_cells

set gated_pins [get_pins "u_usb_cdc.u_sie.u_phy_tx.tx_data_i"]
set_multicycle_path -setup 8 -through $gated_pins
set_multicycle_path -hold 7 -through $gated_pins

set gated_cells [remove_from_collection -intersect [all_registers] [get_cells "u_usb_cdc.u_sie.u_phy_rx.nrzi_q* u_usb_cdc.u_sie.u_phy_rx.rx_state_q* u_usb_cdc.u_sie.u_phy_rx.data_q* u_usb_cdc.u_sie.u_phy_rx.stuffing_cnt_q* u_usb_cdc.u_sie.u_phy_rx.rx_valid_rq* u_usb_cdc.u_sie.u_phy_rx.rx_valid_fq* u_usb_cdc.u_sie.u_phy_rx.reset_cnt_q*"]]
set_multicycle_path -setup 8 -from $gated_cells
set_multicycle_path -hold 7 -from $gated_cells

set gated_pins [get_pins "u_usb_cdc.u_sie.out_ready_o u_usb_cdc.u_sie.in_ready_o"]
set_multicycle_path -setup 8 -through $gated_pins
set_multicycle_path -hold 7 -through $gated_pins

set gated_cells [get_cells -of_objects [all_fanout -from [get_nets u_usb_cdc.u_sie.clk_gate] -flat -trace_arcs all -endpoints_only]]
set_multicycle_path -setup 8 -from $gated_cells
set_multicycle_path -hold 7 -from $gated_cells

set gated_cells [remove_from_collection -intersect [all_registers] [get_cells "u_usb_cdc.u_ctrl_endp.*"]]
set_multicycle_path -setup 64 -from $gated_cells
set_multicycle_path -hold 63 -from $gated_cells
set_multicycle_path -setup 64 -to $gated_cells
set_multicycle_path -hold 63 -to $gated_cells

set gated_pins [get_pins "u_usb_cdc.u_ctrl_endp.out_err_i u_usb_cdc.u_ctrl_endp.setup_i u_usb_cdc.u_ctrl_endp.in_clk_gate_i u_usb_cdc.u_ctrl_endp.in_ready_i u_usb_cdc.u_sie.in_valid_i"]
set_multicycle_path -setup 64 -through $gated_pins
set_multicycle_path -hold 63 -through $gated_pins
