#//////////////////////////////////////////////////////
#/////////////////INCLUDING CROSS-COMPILER/////////////

TOOLCHAIN_PREFIX ?= riscv32-none-elf

CC      = $(TOOLCHAIN_PREFIX)-gcc
OBJDUMP = $(TOOLCHAIN_PREFIX)-objdump
OBJCOPY = $(TOOLCHAIN_PREFIX)-objcopy
READELF = $(TOOLCHAIN_PREFIX)-readelf

#///// flags for RV32I bare-metal ///////////////////
CFLAGS  = -march=rv32im -mabi=ilp32 -Os -ffreestanding -nostdlib -fno-builtin
LDFLAGS = -T link.ld -Wl,-Map=$(@:.elf=.map)

#////Source for c code file ///////////////////////////
SRC_ADDITION     = code_addition.c
SRC_SORT         = code_sort.c
SRC_NEGATIVE     = code_negative.c
SRC_FIBONACCI    = code_fibonacci.c
SRC_XOR          = code_xor.c
SRC_VISION       = code_vision.c      # <--- NEW: Added vision source
SRC_MAIN         = main.c
IMAGE_HEADER     = image_data.h
IMAGE_SOURCE     = test_image.png

TARGET           = code.elf
VISION_TARGET    = vision.elf
.PHONY: all clean vision addition sort negative fibonacci xor main

#/// generating .text file of code cross-compiled from highlevel-c code to risc-v code
# ////////////// Copying and converting the text file into binary files
#/////// Python script to convert the binary files into the required hex files

addition: crt0.s link.ld $(SRC_ADDITION)
	$(CC) $(CFLAGS) $(LDFLAGS) crt0.s $(SRC_ADDITION) -o $(TARGET)
	$(OBJCOPY) -O binary -j .text $(TARGET) ./imem_dmem/imem.bin
	$(OBJCOPY) -O binary -j .data -j .rodata $(TARGET) ./imem_dmem/dmem.bin
	$(OBJDUMP) -d $(TARGET) > ./imem_dmem/code.dis
	cd imem_dmem && python bin2hex.py

sort: crt0.s link.ld $(SRC_SORT)
	$(CC) $(CFLAGS) $(LDFLAGS) crt0.s $(SRC_SORT) -o $(TARGET)
	$(OBJCOPY) -O binary -j .text $(TARGET) ./imem_dmem/imem.bin
	$(OBJCOPY) -O binary -j .data -j .rodata $(TARGET) ./imem_dmem/dmem.bin
	$(OBJDUMP) -d $(TARGET) > ./imem_dmem/code.dis
	cd imem_dmem && python bin2hex.py

negative: crt0.s link.ld $(SRC_NEGATIVE)
	$(CC) $(CFLAGS) $(LDFLAGS) crt0.s $(SRC_NEGATIVE) -o $(TARGET)
	$(OBJCOPY) -O binary -j .text $(TARGET) ./imem_dmem/imem.bin
	$(OBJCOPY) -O binary -j .data -j .rodata $(TARGET) ./imem_dmem/dmem.bin
	$(OBJDUMP) -d $(TARGET) > ./imem_dmem/code.dis
	cd imem_dmem && python bin2hex.py

fibonacci: crt0.s link.ld $(SRC_FIBONACCI)
	$(CC) $(CFLAGS) $(LDFLAGS) crt0.s $(SRC_FIBONACCI) -o $(TARGET)
	$(OBJCOPY) -O binary -j .text $(TARGET) ./imem_dmem/imem.bin
	$(OBJCOPY) -O binary -j .data -j .rodata $(TARGET) ./imem_dmem/dmem.bin
	$(OBJDUMP) -d $(TARGET) > ./imem_dmem/code.dis
	cd imem_dmem && python bin2hex.py

xor: crt0.s link.ld $(SRC_XOR)
	$(CC) $(CFLAGS) $(LDFLAGS) crt0.s $(SRC_XOR) -o $(TARGET)
	$(OBJCOPY) -O binary -j .text $(TARGET) ./imem_dmem/imem.bin
	$(OBJCOPY) -O binary -j .data -j .rodata $(TARGET) ./imem_dmem/dmem.bin
	$(OBJDUMP) -d $(TARGET) > ./imem_dmem/code.dis
	cd imem_dmem && python bin2hex.py

# <--- NEW: Vision Compilation Target --->
# vision: $(SRC_VISION)
# 	$(CC) -c  $(SRC_VISION) $(CFLAGS_FOR_VISION)
# 	$(OBJCOPY) -O binary $(TARGET) ./imem_dmem/imem.bin
# 	$(OBJCOPY) -j .data -O binary $(TARGET) ./imem_dmem/dmem.bin
# 	$(OBJDUMP) -d $(TARGET) > ./imem_dmem/code.dis
# 	cd imem_dmem && python bin2hex.py

vision: crt0.s link.ld $(SRC_VISION)
	$(CC) $(CFLAGS) $(LDFLAGS) crt0.s $(SRC_VISION) -o $(VISION_TARGET)
	$(OBJCOPY) -O binary -j .text $(VISION_TARGET) ./imem_dmem/imem.bin
	$(OBJCOPY) -O binary -j .data -j .rodata $(VISION_TARGET) ./imem_dmem/dmem.bin
	$(OBJDUMP) -d $(VISION_TARGET) > ./imem_dmem/code.dis
	cd imem_dmem && python bin2hex.py

$(IMAGE_HEADER): image_to_c.py $(IMAGE_SOURCE)
	python image_to_c.py $(IMAGE_SOURCE) $(IMAGE_HEADER)

main: crt0.s link.ld $(SRC_MAIN) $(IMAGE_HEADER)
	$(CC) $(CFLAGS) $(LDFLAGS) crt0.s $(SRC_MAIN) -o main.elf
	$(OBJCOPY) -O binary -j .text main.elf ./imem_dmem/imem.bin
	$(OBJCOPY) -O binary -j .data -j .rodata main.elf ./imem_dmem/dmem.bin
	$(OBJDUMP) -d main.elf > ./imem_dmem/code.dis
	cd imem_dmem && python bin2hex.py

# /////clean function
clean:
	$(RM) $(TARGET) $(VISION_TARGET) $(TARGET:.elf=.map) $(VISION_TARGET:.elf=.map) ./imem_dmem/imem.bin ./imem_dmem/imem.hex ./imem_dmem/dmem.bin ./imem_dmem/dmem.hex ./imem_dmem/code.dis