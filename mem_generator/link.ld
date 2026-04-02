OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    DMEM (rwx) : ORIGIN = 0x00001000, LENGTH = 4K
}

_stack_top = ORIGIN(DMEM) + LENGTH(DMEM);

SECTIONS
{
    .text : ALIGN(4)
    {
        KEEP(*(.text.init))
        KEEP(*(.text.init.*))
        *(.text*)
    } > IMEM

    .rodata : ALIGN(4)
    {
        *(.rodata*)
        *(.srodata*)
    } > DMEM

    .data : ALIGN(4)
    {
        PROVIDE(__global_pointer$ = ORIGIN(DMEM) + 0x800);
        *(.data*)
        *(.sdata*)
    } > DMEM

    .bss (NOLOAD) : ALIGN(4)
    {
        _sbss = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        _ebss = .;
    } > DMEM

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}