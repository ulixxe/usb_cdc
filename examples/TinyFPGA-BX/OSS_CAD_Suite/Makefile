
# override the default with: make all PROJ=loopback
PROJ = demo

PIN_DEF = pins.pcf
DEVICE = lp8k
PKG = cm81
IN_DIR = input/$(PROJ)
OUT_DIR = output/$(PROJ)

include $(IN_DIR)/hdl_files.mk

all: $(OUT_DIR)/$(PROJ).rpt $(OUT_DIR)/$(PROJ).bin

$(OUT_DIR):
	mkdir -p $@

$(OUT_DIR)/%.json: $(HDL_FILES) | $(OUT_DIR)
	yosys -l $(OUT_DIR)/log_yosys_$(PROJ).txt -p '$(foreach file,$^,read_verilog $(file);)' -p 'synth_ice40 -top $(PROJ); write_json $@'

$(OUT_DIR)/%.asc: $(OUT_DIR)/%.json $(IN_DIR)/$(PIN_DEF)
	nextpnr-ice40 --$(DEVICE) --package $(PKG) -l $(OUT_DIR)/log_nextpnr_$*.txt --pcf $(IN_DIR)/$(PIN_DEF) --json $< --pre-pack $(IN_DIR)/pre-pack.py --asc $@

$(OUT_DIR)/%.bin: $(OUT_DIR)/%.asc
	icepack $< $@

$(OUT_DIR)/%.rpt: $(OUT_DIR)/%.asc
	icetime -d $(DEVICE) -mtr $@ $<

prog: $(OUT_DIR)/$(PROJ).bin
	tinyprog -p $<

check: $(HDL_FILES)
	verilator --lint-only --default-language 1364-2001 -Wall $^

clean:
	rm -rf $(OUT_DIR)

.SECONDARY:
.PHONY: all prog check clean
