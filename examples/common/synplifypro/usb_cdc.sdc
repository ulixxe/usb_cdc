
####---- USB_CDC constraints ----
set fid [open mylog.txt w]
proc file_puts {fid text collection} {
    puts $fid "\n$text"
    foreach elem [c_list $collection] {
        puts $fid $elem
    }
}

set path "${root_path}.u_sie.u_phy_tx"
set gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.tx_state_q*
    ${path}.bit_cnt_q*
    ${path}.data_q*
    ${path}.stuffing_cnt_q*
    ${path}.nrzi_q*
    ${path}.tx_valid_q*
    "]]
file_puts $fid "00" $gated_cells
set_multicycle_path -setup $BIT_SAMPLES -from $gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -from $gated_cells

set gated_pins [get_pins "
    ${path}.tx_data_i*
    "]
file_puts $fid "01" $gated_pins
set gated_cells [remove_from_collection -intersect [all_registers] [get_cells -of_objects [all_fanout -from $gated_pins -flat -trace_arcs all]]]
file_puts $fid "02" $gated_cells
set_multicycle_path -setup [expr 7 * $BIT_SAMPLES] -to $gated_cells
set_multicycle_path -hold [expr 7 * $BIT_SAMPLES - 1] -to $gated_cells

set path "${root_path}.u_sie.u_phy_rx"
set gated_cells [remove_from_collection -intersect [all_registers] [get_cells "
    ${path}.nrzi_q*
    ${path}.rx_state_q*
    ${path}.data_q*
    ${path}.stuffing_cnt_q*
    ${path}.rx_valid_rq*
    ${path}.rx_valid_fq*
    ${path}.reset_cnt_q*
    "]]
file_puts $fid "03" $gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES / 2] -from $gated_cells
set_multicycle_path -hold [expr ($BIT_SAMPLES / 2) - 1] -from $gated_cells

set path "${root_path}.u_sie"
set gated_pins [get_pins "
    ${path}.out_ready_o
    ${path}.in_ready_o
    "]
file_puts $fid "04" $gated_pins
set gated_cells [remove_from_collection -intersect [all_registers] [get_cells -of_objects [all_fanout -from $gated_pins -flat -trace_arcs all]]]
file_puts $fid "05" $gated_cells
set_multicycle_path -setup [expr 8 * $BIT_SAMPLES] -to $gated_cells
set_multicycle_path -hold [expr 8 * $BIT_SAMPLES - 1] -to $gated_cells

set gated_cells [remove_from_collection -intersect [all_registers] [get_cells -of_objects [all_fanout -from [get_nets "${path}.clk_gate"] -flat -trace_arcs all]]]
file_puts $fid "06" $gated_cells
set_multicycle_path -setup [expr 2 * $BIT_SAMPLES] -from $gated_cells
set_multicycle_path -hold [expr 2 * $BIT_SAMPLES - 1] -from $gated_cells

set gated_cells [remove_from_collection -intersect [all_registers] [get_cells "${root_path}.u_ctrl_endp.*"]]
set gated_cells [remove_from_collection $gated_cells [get_cells "${root_path}.u_ctrl_endp.usb_reset_q"]]
file_puts $fid "07" $gated_cells
set_multicycle_path -setup [expr 8 * $BIT_SAMPLES] -from $gated_cells
set_multicycle_path -hold [expr 8 * $BIT_SAMPLES - 1] -from $gated_cells
set_multicycle_path -setup [expr 8 * $BIT_SAMPLES] -to $gated_cells
set_multicycle_path -hold [expr 8 * $BIT_SAMPLES - 1] -to $gated_cells

set gated_pins [get_pins "
    ${root_path}.u_ctrl_endp.out_err_i
    ${root_path}.u_ctrl_endp.setup_i
    ${root_path}.u_ctrl_endp.in_req_i
    ${root_path}.u_ctrl_endp.in_ready_i
    ${root_path}.u_sie.in_valid_i
    "]
file_puts $fid "08" $gated_pins
set gated_cells [remove_from_collection -intersect [all_registers] [get_cells -of_objects [all_fanout -from $gated_pins -flat -trace_arcs all]]]
file_puts $fid "09" $gated_cells
set_multicycle_path -setup [expr 8 * $BIT_SAMPLES] -to $gated_cells
set_multicycle_path -hold [expr 8 * $BIT_SAMPLES - 1] -to $gated_cells

set gated_cells [remove_from_collection -intersect [all_registers] [get_cells "${root_path}.u_bulk_endp.u_in_fifo.u_*.in_fifo_q*"]]
file_puts $fid "10" $gated_cells
set_multicycle_path -setup [expr $BIT_SAMPLES] -to $gated_cells
set_multicycle_path -hold [expr $BIT_SAMPLES - 1] -to $gated_cells

close $fid
