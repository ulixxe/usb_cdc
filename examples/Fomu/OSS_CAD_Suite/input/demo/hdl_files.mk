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
SB_RAM256x16.v \
rom.v \
ram.v \
app.v \
demo.v \

# Testbench HDL files
TB_HDL_FILES = \
tb_demo.v \

# list of HDL files directories separated by ":"
VPATH = ../../../usb_cdc: \
        ../hdl/demo: \
        ../../common/hdl: \
        ../../common/hdl/ice40: \
