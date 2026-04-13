/* link.ld */
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY
{
  /* Instruction Memory: 4KB starting at 0x00000000 */
  /* imem (rx)  : ORIGIN = 0x00000000, LENGTH = 4K */
  imem (rx)  : ORIGIN = 0x00000048, LENGTH = 4096-72
  /* Data Memory: 4KB. Mapped to 0x1000 so GCC doesn't overlap it with imem */
  /* dmem (rwx) : ORIGIN = 0x00001000, LENGTH = 4K */
  dmem (rwx) : ORIGIN = 0x00001000, LENGTH = 1024

}

SECTIONS
{
  .text : {
    *(.text.init) /* Make sure the startup code goes exactly at 0x00000000 */
    *(.text*)
  } > imem

  .data : {
    *(.data)
    *(.sdata)
    *(.rodata)    /* <--- THIS MUST BE IN THE DMEM SECTION! */
    *(.srodata)
  } > dmem
  
  .bss : {
    *(.bss*)
    *(.sbss*)
  } > dmem
}