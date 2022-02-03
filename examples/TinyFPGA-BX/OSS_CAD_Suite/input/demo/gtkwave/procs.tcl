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

proc monitor {} {
    gtkwave::/Edit/Insert_Comment "MONITOR"
    set sigFilterList [list \
                           {u_usb_monitor\.info} \
                           {u_usb_monitor\.pid} \
                           {u_usb_monitor\.frame} \
                           {u_usb_monitor\.addr} \
                           {u_usb_monitor\.endp} \
                           {u_usb_monitor\.bytes} \
                           {u_usb_monitor\.data} \
                           {u_usb_monitor\.warnings}\
                          ]
    addSignals $sigFilterList
    wavesFormat input/demo/gtkwave
    setData  { {u_usb_monitor\.info} } ASCII
    setColor { {u_usb_monitor\.info} } Blue
    setColor { {u_usb_monitor\.warnings} } Yellow
}

proc top {} {
    gtkwave::/Edit/Insert_Comment "TOP"
    set sigFilterList [list \
                           {^[^.]*\.test\[.*\]$} \
                           {^[^.]*\.dp_sense$} \
                           {^[^.]*\.dn_sense$} \
                           {^[^.]*\.errors$} \
                           {^[^.]*\.csn$} \
                           {^[^.]*\.sck$} \
                           {^[^.]*\.mosi$} \
                           {^[^.]*\.miso$} \
                          ]
    addSignals $sigFilterList
    wavesFormat input/demo/gtkwave
    setData  { {^[^.]*\.test\[.*\]$} } ASCII
    setColor { {^[^.]*\.test\[.*\]$} } Blue
    setColor { {^[^.]*\.errors$} } Red
}

set cmds "app monitor top $cmds"
