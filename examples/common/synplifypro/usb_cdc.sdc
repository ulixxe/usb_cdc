
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
    ${path}.tx_valid_q*
    "]]
file_puts $fid "01" $tx_gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES] -from $tx_gated_cells -to $tx_gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -from $tx_gated_cells -to $tx_gated_cells

set path "${root_path}.u_sie.u_phy_rx"
set rx_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.nrzi_q*
    ${path}.rx_state_q*
    ${path}.data_q*
    ${path}.stuffing_cnt_q*
    ${path}.rx_valid_rq*
    ${path}.rx_valid_fq*
    ${path}.cnt_q*
    ${path}.dp_pu_q*
    ${path}.rx_en_q*
    "]]
file_puts $fid "02" $rx_gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES / 2] -from $rx_gated_cells -to $rx_gated_cells
set_multicycle_path -hold [expr ($BIT_SAMPLES / 2) - 1] -from $rx_gated_cells -to $rx_gated_cells

set path "${root_path}.u_sie"
set sie_gated_cells [remove_from_collection -intersect [all_registers] [get_cells -of_objects [all_fanout -from [get_nets "${path}.clk_gate"] -flat -trace_arcs all]]]
file_puts $fid "03" $sie_gated_cells
set_multicycle_path -setup [expr 2 * $BIT_SAMPLES] -from $sie_gated_cells -to $sie_gated_cells
set_multicycle_path -hold [expr 2 * $BIT_SAMPLES - 1] -from $sie_gated_cells -to $sie_gated_cells

set ctrl_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "${root_path}.u_ctrl_endp.*"]]
set ctrl_gated_cells [remove_from_collection $ctrl_gated_cells [get_cells "${root_path}.u_ctrl_endp.usb_reset_q"]]
set ctrl_gated_cells [remove_from_collection $ctrl_gated_cells [get_cells "${root_path}.u_ctrl_endp.in_req_q"]]
file_puts $fid "04" $ctrl_gated_cells
set_multicycle_path -setup [expr 8 * $BIT_SAMPLES] -from $ctrl_gated_cells -to $ctrl_gated_cells
set_multicycle_path -hold [expr 8 * $BIT_SAMPLES - 1] -from $ctrl_gated_cells -to $ctrl_gated_cells

set path "${root_path}.u_bulk_endp.u_in_fifo"
set in_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.in_first_q*
    ${path}.in_first_qq*
    "]]
set in2_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.u_*.in_fifo_q*
    ${path}.u_*.in_last_q*
    ${path}.u_*.in_ready_q*
    ${path}.u_*.in_ovalid_mask_q*
    "]]
file_puts $fid "05" $in_gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES] -from $in_gated_cells -to $in_gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -from $in_gated_cells -to $in_gated_cells

set path "${root_path}.u_bulk_endp.u_out_fifo"
set out_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.out_fifo_q*
    ${path}.out_last_q*
    ${path}.out_last_qq*
    ${path}.out_state_q*
    ${path}.out_nak_q*
    "]]
set out2_gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.u_*.out_first_q*
    ${path}.u_*.out_full_q*
    ${path}.u_*.out_valid_q*
    ${path}.u_*.out_iready_mask_q*
    ${path}.u_*.out_data_q*
    "]]
file_puts $fid "06" $out_gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES] -from $out_gated_cells -to $out_gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -from $out_gated_cells -to $out_gated_cells

close $fid
