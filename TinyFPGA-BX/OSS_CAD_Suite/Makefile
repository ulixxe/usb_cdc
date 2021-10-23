
PROJ = loopback

PIN_DEF = pins.pcf
DEVICE = lp8k
PKG = cm81
OUT_DIR = output/$(PROJ)

all: $(OUT_DIR)/$(PROJ).rpt $(OUT_DIR)/$(PROJ).bin

$(OUT_DIR):
	mkdir -p $@

$(OUT_DIR)/%.json: %.ys | $(OUT_DIR)
	yosys -l $(OUT_DIR)/log_yosys_$*.txt -s $< -p 'synth_ice40 -top $*; write_json $@'

$(OUT_DIR)/%.asc: $(OUT_DIR)/%.json
	nextpnr-ice40 --$(DEVICE) --package $(PKG) -l $(OUT_DIR)/log_nextpnr_$*.txt --pcf $(PIN_DEF) --json $< --asc $@

$(OUT_DIR)/%.bin: $(OUT_DIR)/%.asc
	icepack $< $@

$(OUT_DIR)/%.rpt: $(OUT_DIR)/%.asc
	icetime -d $(DEVICE) -mtr $@ $<

prog: $(OUT_DIR)/$(PROJ).bin
	tinyprog -p $<

check:
	verilator --lint-only --default-language 1364-2001 -Wall -f $(PROJ)_list.txt

clean:
	rm -rf $(OUT_DIR)

.SECONDARY:
.PHONY: all prog check clean
