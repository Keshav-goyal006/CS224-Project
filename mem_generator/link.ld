/* link.ld */
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY
{
  /* Instruction Memory: 64KB */
  imem (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
  
  /* Data Memory: 64KB */
  dmem (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
  .text : {
    *(.text.init) /* Make sure the startup code goes exactly at 0x00000000 */
    *(.text*)
  } > imem

  /* * THE FIX: AT(0x10000)
   * We force the Load Memory Address (LMA) to offset by 64KB (0x10000).
   * This stops the overlap error, but keeps the execution pointers (VMA) 
   * starting at 0x00000000 inside the > dmem block. 
   */
  .data : AT(0x10000) {
    *(.data)
    *(.sdata)
    *(.rodata)    /* Constant data like your image arrays go here */
    *(.srodata)
  } > dmem
  
  .bss : {
    *(.bss*)
    *(.sbss*)
  } > dmem
}