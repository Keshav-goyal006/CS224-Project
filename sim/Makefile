# --- Variables ---
INC_DIR  = ../modules
BFLAGS   = -i $(INC_DIR) -f filelist.txt
TOP_MOD  = tb_pipeline
TOP_MOD_BOOTLOADER = tb_pipeline_bootloader
SNAPSHOT = riscv_sim
MEM_GEN  = ../mem_generator

# Vivado Tools
XVLOG = xvlog
XELAB = xelab
XSIM  = xsim

.PHONY: help clean sort addition negative fibonacci xor vision bootloader

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

	# 4. Render the testbench output into an image
	python render_output.py simulated_pixels.txt final_output.png --width 64 --height 48 --scale 4
	python render_output.py simulated_pixels_warm.txt final_output_warm.png --width 64 --height 48 --scale 4

bootloader:
	# 1. Generate Hex Files for the integrated bootloader + pipeline build
	$(MAKE) clean -C $(MEM_GEN)
	$(MAKE) vision PATCH_BIT=1 -C $(MEM_GEN)
	cp $(MEM_GEN)/imem_dmem/*.hex .

	# 2. Vivado Simulation Flow
	$(XVLOG) $(BFLAGS)
	$(XELAB) -top $(TOP_MOD_BOOTLOADER) -snapshot $(SNAPSHOT) -debug typical

	# 3. Run Simulation (log to stdout to see $display)
	$(XSIM) $(SNAPSHOT) -runall -log stdout

	# 4. Render the testbench output into an image
	python render_output.py simulated_pixels.txt final_output.png --width 64 --height 48 --scale 4

#   $(XSIM) $(SNAPSHOT) -R

# /////clean function
clean:
	@rm -rf xsim.dir/ .Xil/
	@rm -f stdout*
	@rm -f pipeline.vcd
	@rm -f imem.hex dmem.hex
	@rm -f riscv_sim.wdb # <--- NEW: Cleans up the waveform database file
	@rm -f xvlog.log xvlog.pb xelab.log xelab.pb xsim.log xsim.jou xsim.pb