/* crt0.S */
.section .text.init
.global _start

_start:
    /* Set stack pointer to the top of DMEM (0x1000 + 4096 = 0x2000) */
    li sp, 0x2000
    
    /* Enter the compiled bootloader first. */
    call bootloader_main

    /* Then start the vision application. */
    call main

    /* If main returns, trap the CPU in an infinite loop. */
end_loop:
    j end_loop