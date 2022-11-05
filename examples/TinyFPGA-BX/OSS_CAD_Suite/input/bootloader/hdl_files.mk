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
spi.v \
app.v \
bootloader.v \

# Testbench HDL files
TB_HDL_FILES = \
SB_PLL40_CORE.v \
AT25SF081.v \
usb_monitor.v \
tb_bootloader.v \

# list of HDL files directories separated by ":"
VPATH = ../../../usb_cdc: \
        ../hdl/bootloader: \
        ../../common/hdl: \
        ../../common/hdl/ice40: \
        ../../common/hdl/flash: \
