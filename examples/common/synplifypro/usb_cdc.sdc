
####---- USB_CDC constraints ----
set fid [open mylog.txt w]
proc file_puts {fid text collection} {
    puts $fid "\n$text"
    foreach elem [c_list $collection] {
        puts $fid $elem
    }
}

set path "${root_path}.u_sie.u_phy_tx"
set tx_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.tx_state_q*
    ${path}.bit_cnt_q*
    ${path}.data_q*
    ${path}.stuffing_cnt_q*
    ${path}.nrzi_q*
    "]]
file_puts $fid "01" $tx_gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES] -from $tx_gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -from $tx_gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES] -to $tx_gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -to $tx_gated_cells

set path "${root_path}.u_sie.u_phy_rx"
set rx1_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.rx_state_q*
    ${path}.shift_register_q*
    ${path}.rx_data_q*
    ${path}.stuffing_cnt_q*
    "]]
file_puts $fid "02" $rx1_gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES / 2] -from $rx1_gated_cells -to $rx1_gated_cells
set_multicycle_path -hold [expr ($BIT_SAMPLES / 2) - 1] -from $rx1_gated_cells -to $rx1_gated_cells

set rx2_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.cnt_q*
    ${path}.state_q*
    ${path}.dp_pu_q*
    ${path}.bus_reset_q*
    "]]
file_puts $fid "03" $rx2_gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES] -from $rx2_gated_cells -to $rx2_gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -from $rx2_gated_cells -to $rx2_gated_cells

set rx3_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.rx_valid_qq*
    ${path}.rx_err_qq*
    ${path}.rx_eop_qq*
    ${path}.rx_data_q*
    "]]
set rx3_gated_pins [get_pins "
    ${path}.rx_valid_o*
    ${path}.rx_err_o*
    ${path}.rx_ready_o*
    ${path}.rx_data_o*
    "]
file_puts $fid "04" $rx3_gated_cells
file_puts $fid "05" $rx3_gated_pins
set_multicycle_path -setup [expr $BIT_SAMPLES] -from $rx3_gated_cells -through $rx3_gated_pins
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -from $rx3_gated_cells -through $rx3_gated_pins

set path "${root_path}.u_sie"
set sie_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.*
    "]]
file_puts $fid "06" $sie_gated_cells
set_multicycle_path -setup [expr 1 * $BIT_SAMPLES] -from $sie_gated_cells
set_multicycle_path -hold [expr 1 * $BIT_SAMPLES - 1] -from $sie_gated_cells
set_multicycle_path -setup [expr 1 * $BIT_SAMPLES] -to $sie_gated_cells
set_multicycle_path -hold [expr 1 * $BIT_SAMPLES - 1] -to $sie_gated_cells

set path "${root_path}.u_ctrl_endp"
set ctrl_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.*
    "]]
file_puts $fid "07" $ctrl_gated_cells
set_multicycle_path -setup [expr 1 * $BIT_SAMPLES] -from $ctrl_gated_cells
set_multicycle_path -hold [expr 1 * $BIT_SAMPLES - 1] -from $ctrl_gated_cells
set_multicycle_path -setup [expr 1 * $BIT_SAMPLES] -to $ctrl_gated_cells
set_multicycle_path -hold [expr 1 * $BIT_SAMPLES - 1] -to $ctrl_gated_cells

set path "${root_path}.*u_bulk_endp.u_in_fifo"
set in_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.in_first_q\[*
    ${path}.in_first_qq\[*
    "]]
set in_gated_pins [get_pins "
    ${path}.in_ready_i*
    ${path}.in_data_o*
    ${path}.in_valid_o*
    ${path}.in_empty_o*
    ${path}.in_full_o*
    "]
file_puts $fid "08" $in_gated_cells
file_puts $fid "09" $in_gated_pins
set_multicycle_path -setup [expr $BIT_SAMPLES] -from $in_gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -from $in_gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES] -to $in_gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -to $in_gated_cells

set in2_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.u_*.in_fifo_q*
    ${path}.u_*.in_last_q\[*
    ${path}.u_*.in_last_qq\[*
    "]]
file_puts $fid "10" $in2_gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES] -from $in2_gated_cells -to $in2_gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -from $in2_gated_cells -to $in2_gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES] -from $in2_gated_cells -through $in_gated_pins
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -from $in2_gated_cells -through $in_gated_pins
#set_multicycle_path -setup [expr $BIT_SAMPLES] -to $in2_gated_cells -through $in_gated_pins
#set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -to $in2_gated_cells -through $in_gated_pins

set path "${root_path}.*u_bulk_endp.u_out_fifo"
set out_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.out_fifo_q*
    ${path}.out_last_q\[*
    ${path}.out_last_qq\[*
    ${path}.out_nak_q*
    "]]
set out_gated_pins [get_pins "
    ${path}.out_empty_o*
    ${path}.out_full_o*
    "]
file_puts $fid "11" $out_gated_cells
file_puts $fid "12" $out_gated_pins
set_multicycle_path -setup [expr $BIT_SAMPLES] -from $out_gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -from $out_gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES] -to $out_gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -to $out_gated_cells

set out2_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.u_*.out_first_q*
    "]]
file_puts $fid "13" $out2_gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES] -from $out2_gated_cells -to $out2_gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -from $out2_gated_cells -to $out2_gated_cells
#set_multicycle_path -setup [expr $BIT_SAMPLES] -from $out2_gated_cells -through $out_gated_pins
#set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -from $out2_gated_cells -through $out_gated_pins

set path "${root_path}"
set clk_gate_cell [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.clk_gate_q*
    "]]
file_puts $fid "14" $clk_gate_cell
set_multicycle_path -setup [expr 1] -from $clk_gate_cell
set_multicycle_path -hold [expr 1 - 1] -from $clk_gate_cell

close $fid
