# --- Variables ---
INC_DIR   = ../modules
FILELIST  = filelist.txt
BFLAGS    = -i $(INC_DIR) -f $(FILELIST)
TOP_MOD   = tb_pipeline
SNAPSHOT  = riscv_sim
MEM_GEN   = ../mem_generator
PROGRAMS  = sort addition negative fibonacci xor vision main

# Vivado Tools
XVLOG = xvlog
XELAB = xelab
XSIM  = xsim

.PHONY: help clean compile elab run $(PROGRAMS)

help:
	@echo "Usage: make <program_name>"
	@echo "Programs: $(PROGRAMS)"

# Program flow: build hex -> compile -> elaborate -> simulate
$(PROGRAMS):
	$(MAKE) clean -C $(MEM_GEN)
	$(MAKE) $@ -C $(MEM_GEN)
	cp -f $(MEM_GEN)/imem_dmem/imem.hex .
	cp -f $(MEM_GEN)/imem_dmem/dmem.hex .
	$(MAKE) compile
	$(MAKE) elab
	$(MAKE) run

compile:
	$(XVLOG) $(BFLAGS)

elab:
	$(XELAB) -top $(TOP_MOD) -snapshot $(SNAPSHOT) -debug typical

run:
	$(XSIM) $(SNAPSHOT) -runall -log stdout

# /////clean function
clean:
	@rm -rf xsim.dir/ .Xil/
	@rm -f xvlog.log xvlog.pb xelab.log xelab.pb xsim.log xsim.jou xsim.pb
	@rm -f pipeline.vcd
	@rm -f imem.hex dmem.hex
	@rm -f $(SNAPSHOT).wdb stdout