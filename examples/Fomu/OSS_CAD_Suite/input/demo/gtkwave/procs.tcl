proc app {} {
    gtkwave::/Edit/Insert_Comment "APP"
    set sigFilterList [list \
                           app.cmd_q \
                           app.byte_cnt_q \
                           app.crc32_q \
                           app.data_q \
                           app.lfsr_q \
                           app.state_q]
    addSignals $sigFilterList
    wavesFormat input/demo/gtkwave
    setData { "app.byte_cnt_" } Decimal
}

set cmds "app $cmds"
