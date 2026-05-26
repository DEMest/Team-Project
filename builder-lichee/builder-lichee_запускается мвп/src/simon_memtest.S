#define UART_BASE       0xffe7014000
#define UART_THR        0x00
#define UART_LSR        0x05
#define UART_LSR_THRE   0x20

#define TEST_START      0x40040000
#define TEST_END        0x48000000
#define STEP_SIZE       0x1000

.section .text
.global _start

_start:
    la a0, msg_start
    call puts

    li s0, TEST_START
    li s1, TEST_END
    li s2, 0              # last good addr

test_loop:
    bgeu s0, s1, done

    li t0, 0x1122334455667788
    sd t0, 0(s0)

    ld t1, 0(s0)
    bne t0, t1, bad_mem

    mv s2, s0

    # печатать прогресс раз в 1 MB
    li t2, 0xfffff
    and t3, s0, t2
    bnez t3, no_progress

    la a0, msg_good
    call puts
    mv a0, s0
    call print_hex64
    la a0, msg_newline
    call puts

no_progress:
    li t4, STEP_SIZE
    add s0, s0, t4
    j test_loop

bad_mem:
    la a0, msg_bad
    call puts
    mv a0, s0
    call print_hex64
    la a0, msg_newline
    call puts

    la a0, msg_last
    call puts
    mv a0, s2
    call print_hex64
    la a0, msg_newline
    call puts
    j hang

done:
    la a0, msg_done
    call puts

    la a0, msg_last
    call puts
    mv a0, s2
    call print_hex64
    la a0, msg_newline
    call puts

hang:
    wfi
    j hang


# ---------------- UART ----------------

putc:
    li t0, UART_BASE
wait_tx:
    lbu t1, UART_LSR(t0)
    andi t1, t1, UART_LSR_THRE
    beqz t1, wait_tx
    sb a0, UART_THR(t0)
    ret

puts:
    mv t5, a0
puts_loop:
    lbu a0, 0(t5)
    beqz a0, puts_done
    call putc
    addi t5, t5, 1
    j puts_loop
puts_done:
    ret


# ---------------- HEX PRINT ----------------

print_hex64:
    mv t0, a0

    li a0, '0'
    call putc
    li a0, 'x'
    call putc

    li t1, 60

hex_loop:
    srl t2, t0, t1
    andi t2, t2, 0xf

    li t3, 10
    bltu t2, t3, hex_digit

    addi a0, t2, 87      # 'a' - 10
    j hex_put

hex_digit:
    addi a0, t2, 48      # '0'

hex_put:
    call putc

    addi t1, t1, -4
    bgez t1, hex_loop

    ret


# ---------------- DATA ----------------

.section .rodata

msg_start:
    .asciz "\nMEM STEAL TEST START\n"

msg_good:
    .asciz "good: "

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
