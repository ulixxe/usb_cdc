proc app {} {
    gtkwave::/Edit/Insert_Comment "APP"
    set sigFilterList [list \
                           {app\.cmd_q} \
                           {app\.byte_cnt_q} \
                           {app\.mem_addr_q} \
                           {app\.crc32_q} \
                           {app\.data_q} \
                           {app\.lfsr_q} \
                           {app\.state_q}\
                          ]
    addSignals $sigFilterList
    wavesFormat input/demo/gtkwave
    setData { {app\.byte_cnt_} } Decimal
    setData { {app\.mem_addr_} } Decimal
}


proc top {} {
    gtkwave::/Edit/Insert_Comment "TOP"
    set sigFilterList [list \
                           {^[^.]*\.test\[.*\]$} \
                           {^[^.]*\.dp_sense$} \
                           {^[^.]*\.dn_sense$} \
                           {^[^.]*\.errors$} \
                          ]
    addSignals $sigFilterList
    wavesFormat input/demo/gtkwave
    setData  { {^[^.]*\.test\[.*\]$} } ASCII
    setColor { {^[^.]*\.test\[.*\]$} } Blue
    setColor { {^[^.]*\.errors$} } Red
}

set cmds "app top $cmds"
