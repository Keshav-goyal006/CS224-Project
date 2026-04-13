/* link.ld */
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY {
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 4K
    DMEM (rw) : ORIGIN = 0x00001000, LENGTH = 4K
}
SECTIONS {
    .text : { *(.text*) } > IMEM
    .data : { *(.data*) *(.sdata*) *(.rodata*) } > DMEM
    .bss  : { *(.bss*)  *(.sbss*) } > DMEM
    PROVIDE(__stack_top = ORIGIN(DMEM) + LENGTH(DMEM));
}