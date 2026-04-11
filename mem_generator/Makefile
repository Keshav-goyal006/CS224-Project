#//////////////////////////////////////////////////////
#/////////////////INCLUDING CROSS-COMPILER/////////////

CC      = riscv-none-elf-gcc
AR      = riscv-none-elf-ar
OBJDUMP = riscv-none-elf-objdump
OBJCOPY = riscv-none-elf-objcopy
READELF = riscv-none-elf-readelf

# CC_FOR_VISION = riscv32-unknown-elf-gcc
CC_FOR_VISION = riscv-none-elf-gcc
#///// flags for RV32i architecture///////////////////
CFLAGS  = -march=rv32im -mabi=ilp32
CFLAGS_FOR_VISION =-march=rv32im -mabi=ilp32 -ffreestanding -nostdlib -O0

#////Source for c code file ///////////////////////////
SRC_ADDITION     = code_addition.c
SRC_SORT         = code_sort.c
SRC_NEGATIVE     = code_negative.c
SRC_FIBONACCI    = code_fibonacci.c
SRC_XOR          = code_xor.c
SRC_VISION       = code_vision.c      # <--- NEW: Added vision source
# SRC_VISION       = code_rgba_vision.c      # <--- NEW: Added vision source

TARGET           = code.elf
.PHONY: all clean vision              # <--- NEW: Added vision to phony

#/// generating .text file of code cross-compiled from highlevel-c code to risc-v code
# ////////////// Copying and converting the text file into binary files
#/////// Python script to convert the binary files into the required hex files

addition: $(SRC_ADDITION)
	$(CC) -c  $(SRC_ADDITION) -o $(TARGET) $(CFLAGS)
	$(OBJCOPY) -O binary $(TARGET) ./imem_dmem/imem.bin
	$(OBJCOPY) -j .data -O binary $(TARGET) ./imem_dmem/dmem.bin
	$(OBJDUMP) -d $(TARGET) > ./imem_dmem/code.dis
	cd imem_dmem && python bin2hex.py

sort: $(SRC_SORT)
	$(CC) -c  $(SRC_SORT) -o $(TARGET) $(CFLAGS)
	$(OBJCOPY) -O binary $(TARGET) ./imem_dmem/imem.bin
	$(OBJCOPY) -j .data -O binary $(TARGET) ./imem_dmem/dmem.bin
	$(OBJDUMP) -d $(TARGET) > ./imem_dmem/code.dis
	cd imem_dmem && python bin2hex.py

negative: $(SRC_NEGATIVE)
	$(CC) -c  $(SRC_NEGATIVE) -o $(TARGET) $(CFLAGS)
	$(OBJCOPY) -O binary $(TARGET) ./imem_dmem/imem.bin
	$(OBJCOPY) -j .data -O binary $(TARGET) ./imem_dmem/dmem.bin
	$(OBJDUMP) -d $(TARGET) > ./imem_dmem/code.dis
	cd imem_dmem && python bin2hex.py

fibonacci: $(SRC_FIBONACCI)
	$(CC) -c  $(SRC_FIBONACCI) -o $(TARGET) $(CFLAGS)
	$(OBJCOPY) -O binary $(TARGET) ./imem_dmem/imem.bin
	$(OBJCOPY) -j .data -O binary $(TARGET) ./imem_dmem/dmem.bin
	$(OBJDUMP) -d $(TARGET) > ./imem_dmem/code.dis
	cd imem_dmem && python bin2hex.py

xor: $(SRC_XOR)
	$(CC) -c  $(SRC_XOR) -o $(TARGET) $(CFLAGS)
	$(OBJCOPY) -O binary $(TARGET) ./imem_dmem/imem.bin
	$(OBJCOPY) -j .data -O binary $(TARGET) ./imem_dmem/dmem.bin
	$(OBJDUMP) -d $(TARGET) > ./imem_dmem/code.dis
	cd imem_dmem && python bin2hex.py

# <--- NEW: Vision Compilation Target --->
# vision: $(SRC_VISION)
# 	$(CC) -c  $(SRC_VISION) $(CFLAGS_FOR_VISION)
# 	$(OBJCOPY) -O binary $(TARGET) ./imem_dmem/imem.bin
# 	$(OBJCOPY) -j .data -O binary $(TARGET) ./imem_dmem/dmem.bin
# 	$(OBJDUMP) -d $(TARGET) > ./imem_dmem/code.dis
# 	cd imem_dmem && python bin2hex.py

vision: $(SRC_VISION)
	$(CC_FOR_VISION) $(CFLAGS_FOR_VISION) -T link.ld crt0.S $(SRC_VISION) -o vision.elf
	
	# Extract exactly the instructions for IMEM
	$(OBJCOPY) -O binary -j .text -j .text.init vision.elf ./imem_dmem/imem.bin
	
	# Extract ALL initialized data for DMEM
	$(OBJCOPY) -O binary -j .data -j .sdata -j .rodata vision.elf ./imem_dmem/dmem.bin
	
	$(OBJDUMP) -d vision.elf > ./imem_dmem/code.dis
	cd imem_dmem && python bin2hex.py

# /////clean function
clean:
	$(RM) $(TARGET) ./imem_dmem/imem.bin ./imem_dmem/imem.hex ./imem_dmem/dmem.bin ./imem_dmem/dmem.hex ./imem_dmem/code.dis