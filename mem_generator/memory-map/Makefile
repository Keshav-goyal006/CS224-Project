VIVADO_BIN ?= E:/AMDDesignTools/2025.2/Vivado/bin
UPDATEMEM  ?= "$(VIVADO_BIN)/updatemem.bat"

MMI      ?= riscv.mmi
IMEM_HEX ?= ../imem_dmem/imem.mem
DMEM_HEX ?= ../imem_dmem/dmem.mem
BIT_IN   ?= D:/New/Image_processing/Image_processing.runs/impl_1/top_fpga.bit
BIT_OUT  ?= D:/New/Image_processing/Image_processing.runs/impl_1/fast_update.bit

PROC ?= my_riscv_cpu

.PHONY: flash_fast clean

flash_fast: $(IMEM_HEX) $(DMEM_HEX) $(MMI) $(BIT_IN)
	@echo "Removing old memory files..."
	@rm -f $(BIT_OUT) temp.bit
	@echo "Injecting IMEM..."
	$(UPDATEMEM) -force -meminfo $(MMI) -data $(IMEM_HEX) -proc $(PROC) -bit $(BIT_IN) -out temp.bit
	@echo "Injecting DMEM..."
	$(UPDATEMEM) -force -meminfo $(MMI) -data $(DMEM_HEX) -proc $(PROC) -bit temp.bit -out $(BIT_OUT)
	@rm -f temp.bit
	@test -f "$(BIT_OUT)"
	@echo "Success! Flash $(BIT_OUT) to your FPGA."

clean:
	@echo "Cleaning up generated files..."
	@rm -f $(IMEM_HEX) $(DMEM_HEX) temp.bit *.log *.jou
	@echo "Done."