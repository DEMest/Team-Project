#ifdef QEMU
#define UART0_BASE 0x10000000
#else
#define UART0_BASE 0xD4017000
#endif

#define UART_LSR     0x14
#define LSR_RX_READY 0x01
#define LSR_TX_IDLE  0x20
#define BUFFER_SIZE  0x10

#define DDR_TEST_START 0x12000000
#define DDR_TEST_END   0x70000000
#define DDR_TEST_STEP  0x1000
#define DDR_PRINT_STEP 0x4000000

.global _start
.section .text

_start:
    auipc s1, 0

    la a0, pc_msg
    call puts

    mv a0, s1
    call print_hex

    la a0, newline
    call puts

    la a0, greetings
    call puts

    la a0, code_end_msg
    call puts
    la a0, __code_end
    call print_hex
    la a0, newline
    call puts

    la a0, ddr_range_msg
    call puts
    li a0, DDR_TEST_START
    call print_hex
    la a0, arrow_msg
    call puts
    li a0, DDR_TEST_END
    call print_hex
    la a0, newline
    call puts

    call ddr_full_test

    la a0, cmd_prefix
    call puts

main_loop:
    la s1, buffer
    li s2, 0

input_loop:
    call getc
    call putc

    sb a0, 0(s1)
    addi s1, s1, 1
    addi s2, s2, 1

    li t0, '\r'
    beq a0, t0, process_input
    li t0, '\n'
    beq a0, t0, process_input

    li t0, BUFFER_SIZE
    blt s2, t0, input_loop

process_input:
    sb zero, 0(s1)

    la s3, buffer
    add s3, s3, s2
    addi s3, s3, -1

    lb t0, 0(s3)
    li t1, '\r'
    beq t0, t1, remove_last
    li t1, '\n'
    beq t0, t1, remove_last

    j output

remove_last:
    sb zero, 0(s3)

output:
    la a0, newline
    call puts

    la a0, buffer
    la a1, shtd_cmd
    call strcmp
    beqz a0, shutdown

    la a0, echo_cmd
    call puts
    la a0, buffer
    call puts
    la a0, newline
    call puts
    la a0, cmd_prefix
    call puts

    j main_loop

shutdown:
    la a0, shutdown_msg
    call puts
    j main_loop

# ========================================
# DDR HUGE TEST
# ========================================

ddr_full_test:
    mv s11, ra

    la a0, ddr_test_begin_msg
    call puts

    li s3, DDR_TEST_START
    li s4, DDR_TEST_END
    li s5, 0

ddr_test_loop:
    bgeu s3, s4, ddr_test_done

    li t0, 0x1122334455667788
    sd t0, 0(s3)

    ld t1, 0(s3)
    bne t0, t1, ddr_test_bad

    li t0, 0x8877665544332211
    sd t0, 0(s3)

    ld t1, 0(s3)
    bne t0, t1, ddr_test_bad

    mv s5, s3

    li t2, DDR_PRINT_STEP
    remu t3, s3, t2
    bnez t3, ddr_no_progress

    la a0, ddr_progress_msg
    call puts
    mv a0, s3
    call print_hex
    la a0, newline
    call puts

ddr_no_progress:
    li t4, DDR_TEST_STEP
    add s3, s3, t4
    j ddr_test_loop

ddr_test_bad:
    la a0, ddr_bad_msg
    call puts
    mv a0, s3
    call print_hex
    la a0, newline
    call puts

    la a0, ddr_last_good_msg
    call puts
    mv a0, s5
    call print_hex
    la a0, newline
    call puts

    mv ra, s11
    ret

ddr_test_done:
    la a0, ddr_done_msg
    call puts

    la a0, ddr_last_good_msg
    call puts
    mv a0, s5
    call print_hex
    la a0, newline
    call puts

    mv ra, s11
    ret

strcmp:
strcmp_loop:
    lb t0, 0(a0)
    lb t1, 0(a1)

    bne t0, t1, strcmp_not_equal
    add t2, t0, t1
    beqz t2, strcmp_equal

    addi a0, a0, 1
    addi a1, a1, 1
    j strcmp_loop

strcmp_equal:
    li a0, 0
    ret

strcmp_not_equal:
    li a0, 1
    ret

print_hex:
    mv t3, a0
    li t4, 60
    li t5, UART0_BASE

print_hex_loop:
    srl t0, t3, t4
    andi t0, t0, 0xF

    li t1, 9
    bgt t0, t1, hex_letter

hex_digit:
    addi t0, t0, '0'
    j print_hex_char

hex_letter:
    addi t0, t0, 55

print_hex_char:
wait_tx_hex:
    lb t6, UART_LSR(t5)
    andi t6, t6, LSR_TX_IDLE
    beqz t6, wait_tx_hex

    sb t0, 0(t5)

    addi t4, t4, -4
    bgez t4, print_hex_loop
    ret

getc:
    li t0, UART0_BASE

getc_wait:
    lb t1, UART_LSR(t0)
    andi t1, t1, LSR_RX_READY
    beqz t1, getc_wait
    lb a0, 0(t0)
    ret

putc:
    li t0, UART0_BASE

wait_tx_putc:
    lb t1, UART_LSR(t0)
    andi t1, t1, LSR_TX_IDLE
    beqz t1, wait_tx_putc

    sb a0, 0(t0)
    ret

puts:
    mv t2, a0
    li t3, UART0_BASE

puts_loop:
    lb t4, 0(t2)
    beqz t4, puts_done

wait_tx_puts:
    lb t5, UART_LSR(t3)
    andi t5, t5, LSR_TX_IDLE
    beqz t5, wait_tx_puts

    sb t4, 0(t3)
    addi t2, t2, 1
    j puts_loop

puts_done:
    ret

.align 12
__code_end:

# ========================================
# ДАННЫЕ И СТРОКИ
# ========================================

pc_msg:
    .string "Current PC: 0x"

greetings:
    .string "Coded by Team 42.\r\n"

code_end_msg:
    .string "Normal code ends at: 0x"

ddr_range_msg:
    .string "DDR huge test range: 0x"

arrow_msg:
    .string " -> 0x"

ddr_test_begin_msg:
    .string "DDR HUGE TEST START\r\n"

ddr_progress_msg:
    .string "DDR OK, now at: 0x"

ddr_done_msg:
    .string "DDR HUGE TEST DONE\r\n"

ddr_bad_msg:
    .string "DDR BAD AT: 0x"

ddr_last_good_msg:
    .string "DDR LAST GOOD: 0x"

shutdown_msg:
    .string "shutdown disabled on Lichee\r\n"

cmd_prefix:
    .string "Simon says~: "

newline:
    .string "\r\n"

shtd_cmd:
    .string "shutdown"

echo_cmd:
    .string "echo answered "

.section .bss
.align 12

buffer:
    .space 16

.section .data
.align 12

ddr_touch_padding:
    .space 0x1000000
