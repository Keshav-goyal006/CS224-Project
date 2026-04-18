.PHONY: help clean sort addition negative fibonacci xor vision bootloader

help:
	@echo "Usage: make <target>"
	@echo "Targets: addition, sort, negative, fibonacci, xor, vision, bootloader, clean"

sort addition negative fibonacci xor vision bootloader:
	$(MAKE) -C sim $@

clean:
	$(MAKE) -C sim clean
