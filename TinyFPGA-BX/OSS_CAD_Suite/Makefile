
# override the default with: make all PROJ=loopback
PROJ = demo

PIN_DEF = pins.pcf
DEVICE = lp8k
PKG = cm81
IN_DIR = input/$(PROJ)
OUT_DIR = output/$(PROJ)

all: $(OUT_DIR)/$(PROJ).rpt $(OUT_DIR)/$(PROJ).bin

$(OUT_DIR):
	mkdir -p $@

$(OUT_DIR)/%.json: $(IN_DIR)/read_verilog.ys | $(OUT_DIR)
	yosys -l $(OUT_DIR)/log_yosys_$(PROJ).txt -s $(IN_DIR)/read_verilog.ys -p 'synth_ice40 -top $(PROJ); write_json $@'

$(OUT_DIR)/%.asc: $(OUT_DIR)/%.json $(IN_DIR)/$(PIN_DEF)
	nextpnr-ice40 --$(DEVICE) --package $(PKG) -l $(OUT_DIR)/log_nextpnr_$*.txt --pcf $(IN_DIR)/$(PIN_DEF) --json $< --asc $@

$(OUT_DIR)/%.bin: $(OUT_DIR)/%.asc
	icepack $< $@

$(OUT_DIR)/%.rpt: $(OUT_DIR)/%.asc
	icetime -d $(DEVICE) -mtr $@ $<

prog: $(OUT_DIR)/$(PROJ).bin
	tinyprog -p $<

check: $(IN_DIR)/verilog_list.txt
	verilator --lint-only --default-language 1364-2001 -Wall -f $(IN_DIR)/verilog_list.txt

clean:
	rm -rf $(OUT_DIR)

.SECONDARY:
.PHONY: all prog check clean
