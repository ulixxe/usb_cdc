# HDL files
HDL_FILES = \
phy_tx.v \
phy_rx.v \
sie.v \
ctrl_endp.v \
in_fifo.v \
out_fifo.v \
bulk_endp.v \
usb_cdc.v \
prescaler.v \
loopback_2ch.v \

# Testbench HDL files
TB_HDL_FILES = \
SB_PLL40_CORE.v \
usb_monitor.v \
tb_loopback_2ch.v \

# list of HDL files directories separated by ":"
VPATH = ../../../usb_cdc: \
        ../hdl/loopback_2ch: \
        ../../common/hdl: \
        ../../common/hdl/ice40: \
