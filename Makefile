PROGRESS_LIMIT ?= 50

.PHONY: help clean sort addition negative fibonacci xor vision bootloader progress

help:
	@echo "Usage: make <target>"
	@echo "Targets: addition, sort, negative, fibonacci, xor, vision, bootloader, progress, clean"

sort addition negative fibonacci xor vision bootloader:
	$(MAKE) -C sim $@

progress:
	py scripts/update_readme_progress.py --limit $(PROGRESS_LIMIT)

clean:
	$(MAKE) -C sim clean
