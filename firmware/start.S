/*
 * Minimal RISC-V Bare-Metal Startup Code for PicoRV32
 */

.section .text.start
.global _start
.type _start, @function

_start:
    /* 1. Initialize stack pointer to top of BRAM */
    la sp, _stack_top

    /* 2. Clear BSS segment to 0 */
    la t0, _bss_start
    la t1, _bss_end
zero_bss_loop:
    bgeu t0, t1, zero_bss_done
    sw zero, 0(t0)
    addi t0, t0, 4
    j zero_bss_loop
zero_bss_done:

    /* 3. Call C application main() */
    call main

    /* 4. If main returns, loop infinitely */
hang:
    j hang

.size _start, . - _start
