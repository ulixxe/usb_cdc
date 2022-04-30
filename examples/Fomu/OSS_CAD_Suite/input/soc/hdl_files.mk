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
fifo_if.v \
app.v \
soc.v \

# Testbench HDL files
TB_HDL_FILES = \
tb_soc.v \

# list of HDL files directories separated by ":"
VPATH = ../../../usb_cdc: \
        ../hdl/soc: \
        ../../common/hdl: \
        ../../common/hdl/ice40: \
