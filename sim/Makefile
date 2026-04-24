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

.PHONY: help clean sort addition negative fibonacci xor vision bootloader timing_9x9 timing_9x9_latency timing_5x5_direct

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

bootloader: TOP_MOD = tb_pipeline_bootloader
bootloader:
	# 1. Generate Hex Files
	$(MAKE) clean -C $(MEM_GEN)
	$(MAKE) $@ -C $(MEM_GEN)
	cp $(MEM_GEN)/imem_dmem/*.hex .
	python gen_rgb_bootloader_input.py --input ../mem_generator/image_data_rgb.h --output original_image_rgb_bytes.txt

	# 2. Vivado Simulation Flow
	$(XVLOG) $(BFLAGS)
	$(XELAB) -top $(TOP_MOD) -snapshot $(SNAPSHOT) -debug typical

	# 3. Run Simulation (log to stdout to see $display)
	$(XSIM) $(SNAPSHOT) -runall -log stdout
	python rgb_img.py

# <--- NEW: 9x9 Stream Accelerator Timing Test --->
timing_9x9: TOP_MOD = tb_stream_accel_5x5_rgb_timing
timing_9x9:
	# 1. Generate 9x9 Image and Hex Files
	$(MAKE) clean -C $(MEM_GEN)
	$(MAKE) timing_9x9 -C $(MEM_GEN)
	cp $(MEM_GEN)/imem_dmem/*.hex .
	python gen_9x9_bootloader_input.py

	# 2. Vivado Simulation Flow
	$(XVLOG) $(BFLAGS)
	$(XELAB) -top $(TOP_MOD) -snapshot $(SNAPSHOT) -debug typical

	# 3. Run Simulation (log timing to file)
	$(XSIM) $(SNAPSHOT) -runall -log stdout

timing_9x9_latency: TOP_MOD = tb_pipeline_bootloader_9x9_latency
timing_9x9_latency:
	# 1. Generate 9x9 image bytes + program hex
	$(MAKE) clean -C $(MEM_GEN)
	$(MAKE) timing_9x9 -C $(MEM_GEN)
	cp $(MEM_GEN)/imem_dmem/*.hex .
	python gen_9x9_bootloader_input.py

	# 2. Vivado Simulation Flow
	$(XVLOG) $(BFLAGS)
	$(XELAB) -top $(TOP_MOD) -snapshot $(SNAPSHOT) -debug typical

	# 3. Run Simulation (per-pixel latency written to latency_9x9_ifid_to_uart.txt)
	$(XSIM) $(SNAPSHOT) -runall -log stdout

timing_5x5_direct: TOP_MOD = tb_stream_accel_5x5_timing
timing_5x5_direct:
	# Direct module simulation only (no mem_generator / no bitstream changes)
	$(XVLOG) $(BFLAGS)
	$(XELAB) -top $(TOP_MOD) -snapshot $(SNAPSHOT) -debug typical
	$(XSIM) $(SNAPSHOT) -runall -log stdout

#   $(XSIM) $(SNAPSHOT) -R

# /////clean function
clean:
	@rm -rf xsim.dir/ .Xil/
	@rm -f xvlog.log xvlog.pb xelab.log xelab.pb xsim.log xsim.jou xsim.pb
	@rm -f pipeline.vcd
	@rm -f imem.hex dmem.hex # <--- NEW: Cleans up the copied hex files in this dir
	@rm -f original_image_rgb_bytes.txt image_9x9_rgb_bytes.txt
	# 	$(MAKE) clean -C $(MEM_GEN) # <--- NEW: Also cleans up the mem_generator directory
	@rm -f riscv_sim.wdb # <--- NEW: Cleans up the waveform database file
	@rm -f stdout stream_accel_timing_log.txt stream_accel_5x5_timing_log.txt latency_9x9_ifid_to_uart.txt