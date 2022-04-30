
proc addSignals {sigFilterList} {
    foreach sigFilter $sigFilterList {
        for {set i 0} {$i < [ gtkwave::getNumFacs ] } {incr i} {
            set facname [gtkwave::getFacName $i]
            set index [regexp $sigFilter $facname]
            if {$index == 1} {
                gtkwave::addSignalsFromList "$facname"
            }
        }
    }
}

proc setColor {sigFilterList color} {
    gtkwave::/Edit/UnHighlight_All
    foreach sigFilter $sigFilterList {
        for {set i 0} {$i < [ gtkwave::getNumFacs ] } {incr i} {
            set facname [gtkwave::getFacName $i]
            set index [regexp $sigFilter $facname]
            if {$index == 1} {
                gtkwave::highlightSignalsFromList "$facname"
            }
        }
    }
    gtkwave::/Edit/Color_Format/$color
    gtkwave::/Edit/UnHighlight_All
}

proc setData {sigFilterList data} {
    gtkwave::/Edit/UnHighlight_All
    foreach sigFilter $sigFilterList {
        for {set i 0} {$i < [ gtkwave::getNumFacs ] } {incr i} {
            set facname [gtkwave::getFacName $i]
            set index [regexp $sigFilter $facname]
            if {$index == 1} {
                gtkwave::highlightSignalsFromList "$facname"
            }
        }
    }
    gtkwave::/Edit/Data_Format/$data
    gtkwave::/Edit/UnHighlight_All
}

proc getConfig {mapfile} {
    set fd [open $mapfile r]
    set data [read $fd]
    close $fd

    set data_lines [split $data "\n"]
    set config_lines [lsearch -all -regexp $data_lines "^(\\s)*##.*##.*$"]
    set config_dict [dict create]
    foreach line $config_lines {
        set config_data [split [string map [list "##" \001] [lindex $data_lines $line]] \001]
        set key [string trim [lindex $config_data 1]]
        set value [string trim [lindex $config_data 2]]
        if { $key == "name"} {
            dict lappend config_dict $key $value
        } else {
            dict set config_dict $key $value
        }
    }
    return $config_dict
}

proc wavesTranslate {mapfile} {
    set config_dict [getConfig $mapfile]
    if {[dict exists $config_dict {name}]} {
        gtkwave::/Edit/UnHighlight_All
        foreach sigFilter [dict get $config_dict {name}] {
            for {set i 0} {$i < [gtkwave::getNumFacs] } {incr i} {
                set facname [gtkwave::getFacName $i]
                set index [regexp $sigFilter $facname]
                if {$index == 1} {
                    gtkwave::highlightSignalsFromList "$facname"
                }
            }
        }
        if {[dict exists $config_dict {color}]} {
            gtkwave::/Edit/Color_Format/[dict get $config_dict {color}]
        }
        if {[dict exists $config_dict {data}]} {
            gtkwave::/Edit/Data_Format/[dict get $config_dict {data}]
        }
        gtkwave::installFileFilter [gtkwave::setCurrentTranslateFile $mapfile]
        gtkwave::/Edit/UnHighlight_All
    }
}

proc wavesFormat {mapdir} {
    set files [ glob $mapdir/*.map ]
    foreach file $files {
        wavesTranslate $file
    }
}

proc phy_rx {} {
    gtkwave::/Edit/Insert_Comment "PHY_RX"
    set sigFilterList [list \
                           {phy_rx\.nrzi\[} \
                           {phy_rx\.rx_state_q} \
                           {phy_rx\.clk_gate$} \
                           {phy_rx\.rx_en_i$} \
                           {phy_rx\.rx_err_o$} \
                           {phy_rx\.rx_ready_o$} \
                           {phy_rx\.rx_valid_o$} \
                           {phy_rx\.rx_data_o\[.*\]$} \
                           {phy_rx\.usb_reset_o$} \
                           {phy_rx\.dp_pu_o$} \
                          ]
    addSignals $sigFilterList
    wavesFormat ../../common/gtkwave
}

proc phy_tx {} {
    gtkwave::/Edit/Insert_Comment "PHY_TX"
    set sigFilterList [list \
                           {phy_tx\.tx_state_q} \
                           {phy_tx\.clk_gate} \
                           {phy_tx\.tx_ready_o} \
                           {phy_tx\.tx_valid_i} \
                           {phy_tx\.tx_data_i} \
                          ]
    addSignals $sigFilterList
    wavesFormat ../../common/gtkwave
}

proc sie {} {
    gtkwave::/Edit/Insert_Comment "SIE"
    set sigFilterList [list \
                           {sie\.frame_q} \
                           {sie\.pid_q} \
                           {sie\.addr_q} \
                           {sie\.endp_q} \
                           {sie\.phy_state_q} \
                           {sie\.stall_i} \
                           {sie\.setup_o} \
                          ]
    addSignals $sigFilterList
    wavesFormat ../../common/gtkwave
}

proc sie_out {} {
    gtkwave::/Edit/Insert_Comment "SIE: OUT"
    set sigFilterList [list \
                           {sie\.out_err_o} \
                           {sie\.out_ready_o} \
                           {sie\.out_valid_o} \
                           {sie\.out_data_o} \
                          ]
    addSignals $sigFilterList
    wavesFormat ../../common/gtkwave
}

proc sie_in {} {
    gtkwave::/Edit/Insert_Comment "SIE: IN"
    set sigFilterList [list \
                           {sie\.in_req_o} \
                           {sie\.in_ready_o} \
                           {sie\.in_valid_i} \
                           {sie\.in_zlp_i} \
                           {sie\.in_data_i} \
                          ]
    addSignals $sigFilterList
    wavesFormat ../../common/gtkwave
}

proc ctrl {} {
    gtkwave::/Edit/Insert_Comment "CTRL_ENDP"
    set sigFilterList [list \
                           {ctrl_endp\.dev_state_qq} \
                           {ctrl_endp\.addr_o} \
                           {ctrl_endp\.stall_o} \
                          ]
    addSignals $sigFilterList
    wavesFormat ../../common/gtkwave
}

proc bulk_out {} {
    gtkwave::/Edit/Insert_Comment "BULK_ENDP: OUT"
    set sigFilterList [list \
                           {bulk_endp\.app_clk_i} \
                           {bulk_endp\.app_out_ready_i} \
                           {bulk_endp\.app_out_valid_o} \
                           {bulk_endp\.app_out_data_o} \
                           {out_fifo\.out_state_q} \
                           {out_fifo\.out_full_q} \
                           {out_fifo\.out_empty} \
                          ]
    addSignals $sigFilterList
    wavesFormat ../../common/gtkwave
}

proc bulk_in {} {
    gtkwave::/Edit/Insert_Comment "BULK_ENDP: IN"
    set sigFilterList [list \
                           {bulk_endp\.app_clk_i} \
                           {bulk_endp\.app_in_ready_o} \
                           {bulk_endp\.app_in_valid_i} \
                           {bulk_endp\.app_in_data_i} \
                           {in_fifo\.in_state_q} \
                           {in_fifo\.in_full} \
                          ]
    addSignals $sigFilterList
    wavesFormat ../../common/gtkwave
    setColor { {in_fifo\.in_state_q} } Blue
}

proc out {} {
    phy_rx
    sie
    sie_out
    bulk_out
}

proc in {} {
    bulk_in
    sie
    sie_in
    phy_tx
}

set cmds "out in phy_rx phy_tx sie sie_out sie_in ctrl bulk_in bulk_out"
if { [file exists input/$env(PROJ)/gtkwave/procs.tcl]} {
    source input/$env(PROJ)/gtkwave/procs.tcl
}

puts "\033\[92m"
puts "gtkwave console"
puts "Available commands to show waveforms:"
puts "  $cmds"
puts "\033\[0m"
