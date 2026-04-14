# --- Variables ---
INC_DIR  = ../modules
BFLAGS   = -i $(INC_DIR) -f filelist.txt
TOP_MOD  = tb_pipeline
SNAPSHOT = riscv_sim
MEM_GEN  = ../mem_generator

# Vivado Tools
XVLOG = xvlog
XELAB = xelab
XSIM  = xsim

.PHONY: help clean sort addition negative fibonacci xor vision

help:
	@echo "Usage: make <program_name> (e.g. make addition or make vision)"

# Generic Rule for all programs
sort addition negative fibonacci xor vision:
	# 1. Generate Hex Files
	$(MAKE) clean -C $(MEM_GEN)
	$(MAKE) $@ -C $(MEM_GEN)
	cp $(MEM_GEN)/imem_dmem/*.hex .

	# 2. Vivado Simulation Flow
	$(XVLOG) $(BFLAGS)
	$(XELAB) -top $(TOP_MOD) -snapshot $(SNAPSHOT) -debug typical
	
	# 3. Run Simulation (log to stdout to see $display)
	$(XSIM) $(SNAPSHOT) -runall -log stdout

#   $(XSIM) $(SNAPSHOT) -R

# /////clean function
clean:
	@rm -rf xsim.dir/ .Xil/
	@rm -f xvlog.log xvlog.pb xelab.log xelab.pb xsim.log xsim.jou xsim.pb
	@rm -f pipeline.vcd
	@rm -f imem.hex dmem.hex # <--- NEW: Cleans up the copied hex files in this dir
	$(MAKE) clean -C $(MEM_GEN) # <--- NEW: Also cleans up the mem_generator directory
	@rm -f riscv_sim.wdb # <--- NEW: Cleans up the waveform database file
	@rm -f stdout