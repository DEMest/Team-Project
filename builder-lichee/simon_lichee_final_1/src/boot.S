#ifdef QEMU
#define UART0_BASE     0x10000000
#define UART_LSR       5
#define LSR_TX_IDLE    0x20
#else
#define UART0_BASE     0xFFE7014000
#define UART_LSR       0x14
#define LSR_TX_IDLE    0x20
#endif
#define SRAM_SIZE      0x17FFFF
#define STACK_OFFSET   SRAM_SIZE
#define PAYLOAD_OFFSET 0x10000

#define NEWLINE        0xA
#define HASH           0x23
#define SEMICOLON      0x3B
#define F_LOWERCASE    0x66
#define F_UPPERCASE    0x46
#define A_LOWERCASE    0x61
#define A_UPPERCASE    0x41
#define DIGIT_9        0x39
#define DIGIT_0        0x30

.global _start
.section .text

#------------------------------------------------------------
# 
# SRAM_BASE = 0x80000000 for QEMU virt
# DDR_BASE  = 0x40000000 on Lichee Pi 4A via U-Boot
#   
# Memory:
#   SRAM_BASE - (SRAM_BASE + 0x40000)  stage1 + payload source
# > (SRAM_BASE + 0x40000)              compiled payload
# < (SRAM_BASE + SRAM_SIZE)            m-mode stack
# 
#------------------------------------------------------------

_start:
        call ddr_early_warmup

        la a0, greetings
        call puts

        auipc s11, 0
        li s10, STACK_OFFSET
        add sp, s11, s10
        li s10, PAYLOAD_OFFSET
        add s11, s11, s10

        la s1, payload_src
        li s3, 0
        mv s5, s11
                
        # s1 -- source address
        # s2 -- read byte
        # s3 -- digit read flag
        # s4 -- digit buffer
        # s5 -- write address
        read_loop:
                lb s2, (s1)
                addi s1, s1, 1
                beqz s2, read_loop_exit

                li s6, HASH
                beq s2, s6, skip_comment
                li s6, SEMICOLON
                beq s2, s6, skip_comment
                
                li s6, (F_LOWERCASE + 1)
                bge s2, s6, read_loop_cont

                li s6, A_LOWERCASE
                bge s2, s6, handle_lower

                li s6, (F_UPPERCASE + 1)
                bge s2, s6, read_loop_cont

                li s6, A_UPPERCASE
                bge s2, s6, handle_upper

                li s6, (DIGIT_9 + 1)
                bge s2, s6, read_loop_cont

                li s6, DIGIT_0
                bge s2, s6, handle_digit

                j read_loop_cont

                skip_comment:                
                        li s6, NEWLINE
                skip_comment_loop:
                        lb s2, (s1)
                        addi s1, s1, 1
                        beq s2, s6, skip_comment_loop_end
                        j skip_comment_loop
                skip_comment_loop_end:
                        j read_loop_cont                         
                
                handle_digit:
                        addi s2, s2, -(DIGIT_0)
                        j general_handle                        
                handle_lower:
                        addi s2, s2, -(A_LOWERCASE - 10)
                        j general_handle
                handle_upper:
                        addi s2, s2, -(A_UPPERCASE - 10)

                general_handle:
                        slli s4, s4, 4
                        andi s4, s4, 0xFF
                        add s4, s4, s2
                        beqz s3, set_flag
                        sb s4, (s5)
                        addi s5, s5, 1

                        set_flag:
                        not s3, s3

                read_loop_cont:
                j read_loop
        read_loop_exit:
                beqz s3, read_loop_end
                andi s4, s4, 0xF
                sb s4, (s5)                
        read_loop_end:

        la a0, builded
        call puts

        mv a0, s1
        jalr zero, (s11) 

# Ранний прогрев DDR. Не трогаем начало образа и место, куда boot декодирует Simon.
# Нужно для Lichee, где дальше Simon использует рабочие структуры в 0x40050000+.
ddr_early_warmup:
    li t0, 0x40050000
    li t1, 0x40200000
    li t2, 0xA5A5A5A5A5A5A5A5
1:
    sd t2, 0(t0)
    ld t3, 0(t0)
    addi t0, t0, 8
    bltu t0, t1, 1b
    ret

puts:
    mv t1, a0
    li t2, UART0_BASE
puts_loop:
    lb a0, (t1)
    beqz a0, puts_done
puts_wait_tx:
    lb t3, UART_LSR(t2)
    andi t3, t3, LSR_TX_IDLE
    beqz t3, puts_wait_tx
    sb a0, 0(t2)
    addi t1, t1, 1
    j puts_loop
puts_done:
    ret

greetings: .string "[BOOTED]: Stage 1 (boot) - coded by ylab-nsu.\n\r"
builded: .string "[BUILDED]: Jump to stage 2.   \n\n\r"

payload_src: