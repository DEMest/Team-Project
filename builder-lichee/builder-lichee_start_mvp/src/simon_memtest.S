#define UART_BASE       0xffe7014000
#define UART_THR        0x00
#define UART_LSR        0x05
#define UART_LSR_THRE   0x20

#define TEST_START      0x40040000
#define TEST_END        0x41000000
#define STEP_SIZE       0x1000

.section .text
.global _start

_start:
    la a0, msg_start
    call puts

    la a0, msg_code_end
    call puts
    la a0, __code_end
    call puth

    la a0, msg_test_start
    call puts
    li a0, TEST_START
    call puth

    la a0, msg_test_end
    call puts
    li a0, TEST_END
    call puth

    la a0, msg_testing
    call puts

    li s0, TEST_START
    li s1, TEST_END
    li s2, 0

test_loop:
    bgeu s0, s1, done

    li t0, 0x1122334455667788
    sd t0, 0(s0)

    ld t1, 0(s0)
    bne t0, t1, bad_mem

    mv s2, s0

    # печать раз в 1 MB
    li t2, 0xfffff
    and t3, s0, t2
    bnez t3, no_progress

    la a0, msg_good
    call puts
    mv a0, s0
    call puth

no_progress:
    li t4, STEP_SIZE
    add s0, s0, t4
    j test_loop

bad_mem:
    la a0, msg_bad
    call puts
    mv a0, s0
    call puth

    la a0, msg_last
    call puts
    mv a0, s2
    call puth

    j hang

done:
    la a0, msg_done
    call puts

    la a0, msg_last
    call puts
    mv a0, s2
    call puth

hang:
    wfi
    j hang


putc:
    li t0, UART_BASE

putc_wait:
    lbu t1, UART_LSR(t0)
    andi t1, t1, UART_LSR_THRE
    beqz t1, putc_wait

    sb a0, UART_THR(t0)
    ret


puts:
    mv t5, a0

puts_loop:
    lbu a0, 0(t5)
    beqz a0, puts_done

    li t0, UART_BASE

puts_wait:
    lbu t1, UART_LSR(t0)
    andi t1, t1, UART_LSR_THRE
    beqz t1, puts_wait

    sb a0, UART_THR(t0)

    addi t5, t5, 1
    j puts_loop

puts_done:
    ret


puth:
    mv t4, a0

    li a0, '0'
    call putc
    li a0, 'x'
    call putc

    li t2, 60

puth_loop:
    srl t3, t4, t2
    andi t3, t3, 0xf

    li t6, 10
    bltu t3, t6, puth_digit

    addi a0, t3, 87
    j puth_put

puth_digit:
    addi a0, t3, 48

puth_put:
    call putc

    addi t2, t2, -4
    bgez t2, puth_loop

    la a0, msg_newline
    call puts

    ret


.align 12
__code_end:


.section .rodata

msg_start:
    .asciz "\nMEM STEAL TEST START\n"

msg_code_end:
    .asciz "CODE END:   "

msg_test_start:
    .asciz "TEST START: "

msg_test_end:
    .asciz "TEST END:   "

msg_testing:
    .asciz "TESTING...\n"

msg_good:
    .asciz "GOOD: "

msg_bad:
    .asciz "BAD MEM AT: "

msg_last:
    .asciz "LAST GOOD: "

msg_done:
    .asciz "MEM TEST DONE\n"

msg_newline:
    .asciz "\n"


.section .data
.align 12

ddr_touch_padding:
    .space 0x1000000
