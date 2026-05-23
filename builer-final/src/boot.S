#define UART0_BASE     0x10000000
#define SRAM_SIZE      0x17FFFF
#define STACK_OFFSET   SRAM_SIZE

# PAYLOAD_OFFSET — это смещение от _start, куда boot пишет скомпилированный simon.
# Источник (boot.bin + simon.hex0 + payload-секция в hex0/hex1) лежит начиная с _start.
# Если источник больше PAYLOAD_OFFSET, он перекрывается с записываемой simon-областью.
# Увеличил с 0x1fff4 до 0x80000 (= 512 KB), чтобы было достаточно места под:
#   boot.bin  (~1 KB)
#   simon.hex0  (~14 KB)
#   hex1.hex0   (~24 KB)
#   hex2.hex1   (~24 KB)
#   и любые другие исходники в payload-секции
#
# При увеличении этого смещения simon binary окажется выше, и теперь у нас
# зона для исходников расширилась с ~128 KB до ~512 KB.
#
# Важно: simon в своей карте памяти всё ещё ожидает свою область с 0x80010000,
# но это лишь информационная карта (simon сам себя позиционирует через -Ttext
# при сборке gcc). Реальный entry point боот передаёт через jalr (s11).
#
# При желании можно ещё больше: вплоть до примерно (SRAM_SIZE - размер_simon).
#
#define PAYLOAD_OFFSET 0x80000

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
# SRAM_BASE = 0xFFE0000000 on real Lichee Pi 4A
#   
# Memory:
#   SRAM_BASE - (SRAM_BASE + PAYLOAD_OFFSET)  stage1 + payload sources
# > (SRAM_BASE + PAYLOAD_OFFSET)              compiled simon (stage 2)
# < (SRAM_BASE + SRAM_SIZE)                   m-mode stack
# 
#------------------------------------------------------------

_start:
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

puts:
    mv t1, a0
    li t2, UART0_BASE
puts_loop:
    lb a0, (t1)
    beqz a0, puts_done
    sb a0, 0(t2)
    addi t1, t1, 1
    j puts_loop
puts_done:
    ret

greetings: .string "[BOOTED]: Stage 1 (boot) - coded by ylab-nsu.\n\r"
builded: .string "[BUILDED]: Jump to stage 2.   \n\n\r"

payload_src: