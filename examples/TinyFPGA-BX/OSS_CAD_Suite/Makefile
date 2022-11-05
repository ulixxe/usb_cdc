
# override the default with: make all PROJ=loopback
PROJ = demo

PIN_DEF = pins.pcf
DEVICE = lp8k
PKG = cm81
IN_DIR = input/$(PROJ)
OUT_DIR = output/$(PROJ)
INC_DIRS = -I../../common/hdl -I../hdl/$(PROJ)
ICE40_LIB = $(shell yosys-config --datdir/ice40/cells_sim.v)
RUN_ONCE =
run = $(if $(RUN_ONCE),$(1),until $$($(1)) ; do true ; done)

include $(IN_DIR)/hdl_files.mk

all: $(OUT_DIR)/$(PROJ).rpt $(OUT_DIR)/$(PROJ).bin
fw: $(OUT_DIR)/fw_$(PROJ).bin

$(OUT_DIR):
	mkdir -p $@

$(OUT_DIR)/%.json: $(HDL_FILES) | $(OUT_DIR)
	yosys -l $(OUT_DIR)/log_yosys_$(PROJ).txt -p '$(foreach file,$^,read_verilog $(file);)' -p 'synth_ice40 -top $(PROJ); write_json $@'

$(OUT_DIR)/%.asc: $(OUT_DIR)/%.json $(IN_DIR)/$(PIN_DEF)
	$(call run,nextpnr-ice40 --randomize-seed --$(DEVICE) --package $(PKG) -l $(OUT_DIR)/log_nextpnr_$*.txt --pcf $(IN_DIR)/$(PIN_DEF) --json $< --pre-pack $(IN_DIR)/pre-pack.py --asc $@)

$(OUT_DIR)/%.rpt: $(OUT_DIR)/%.asc
	icetime -d $(DEVICE) -mtr $@ $<

$(OUT_DIR)/%.bin: $(OUT_DIR)/%.asc
	icepack $< $@

$(OUT_DIR)/fw_%.bin: $(OUT_DIR)/%.bin
	cp $< $(OUT_DIR)/$*_0.bin 
	cp $< $(OUT_DIR)/$*_1.bin 
	icemulti -v -o $@ -a15 -p0 $(OUT_DIR)/$*_0.bin $(OUT_DIR)/$*_1.bin
	rm $(OUT_DIR)/$*_0.bin $(OUT_DIR)/$*_1.bin

prog: $(OUT_DIR)/$(PROJ).bin
	tinyprog -p $<

lint: $(HDL_FILES)
	verilator --lint-only --default-language 1364-2001 -Wall -Wno-UNUSED -Wno-UNDRIVEN -Wno-TIMESCALEMOD -DBLACKBOX -DNO_ICE40_DEFAULT_ASSIGNMENTS --top $(PROJ) $(INC_DIRS) -v $(ICE40_LIB) $^

$(OUT_DIR)/cells_sim.v:
	patch $(ICE40_LIB) -o $(OUT_DIR)/cells_sim.v < ../../common/hdl/ice40/cells_sim.v.patch

$(OUT_DIR)/%.vvp: $(HDL_FILES) $(TB_HDL_FILES) | $(OUT_DIR) $(OUT_DIR)/cells_sim.v
	iverilog -g2001 -DNO_ICE40_DEFAULT_ASSIGNMENTS -t vvp -s tb_$(PROJ) $(INC_DIRS) -l $(OUT_DIR)/cells_sim.v -o $@ $^

$(OUT_DIR)/%.fst: $(OUT_DIR)/%.vvp
	vvp -N $< -fst && mv tb.dump $@

sim: $(OUT_DIR)/$(PROJ).fst

$(OUT_DIR)/%.xml: $(HDL_FILES) $(TB_HDL_FILES) | $(OUT_DIR) $(OUT_DIR)/cells_sim.v
	verilator -xml-only --bbox-unsup --bbox-sys -Wno-lint -Wno-TIMESCALEMOD -Wno-STMTDLY -Wno-INFINITELOOP -DBLACKBOX -DNO_ICE40_DEFAULT_ASSIGNMENTS --top tb_$(PROJ) $(INC_DIRS) -v $(OUT_DIR)/cells_sim.v $^ --xml-output $@

$(OUT_DIR)/%.stems: $(OUT_DIR)/%.xml
	xml2stems $< $@

wave: $(OUT_DIR)/$(PROJ).stems $(OUT_DIR)/$(PROJ).fst
	gtkwave --autosavename --saveonexit --tcl_init=../../common/gtkwave/procs.tcl --wish --stems $^ --rcvar 'do_initial_zoom_fit yes' --rcvar 'splash_disable yes'

clean:
	rm -rf $(OUT_DIR)

.SECONDARY:
.PHONY: all prog lint sim wave clean
