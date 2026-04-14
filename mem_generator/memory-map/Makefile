VIVADO_BIN ?= E:/AMDDesignTools/2025.2/Vivado/bin
UPDATEMEM  ?= "$(VIVADO_BIN)/updatemem.bat"

MMI      ?= riscv.mmi
IMEM_HEX ?= ../imem_dmem/imem.mem
DMEM_HEX ?= ../imem_dmem/dmem.mem
BIT_IN   ?= D:/New/Image_processing/Image_processing.runs/impl_1/top_fpga.bit
BIT_OUT  ?= D:/New/Image_processing/Image_processing.runs/impl_1/fast_update.bit

.PHONY: flash_fast clean

flash_fast: 
	@echo "Injecting IMEM..."
# 	$(UPDATEMEM) -force -meminfo $(MMI) -data $(IMEM_HEX) -proc IMEM_CORE -bit $(BIT_IN) -out temp.bit
	@echo "Injecting DMEM..."
	$(UPDATEMEM) -force -meminfo $(MMI) -data $(DMEM_HEX) -proc DMEM_CORE -bit $(BIT_IN) -out $(BIT_OUT)
	@echo "Cleaning temp file..."
# 	@del temp.bit
	@echo "Success! Flash $(BIT_OUT) to your FPGA."

clean:
	@echo "Cleaning up generated files..."
	$(RM) -f $(IMEM_HEX) $(DMEM_HEX) *.log *.jou
	@echo "Done."