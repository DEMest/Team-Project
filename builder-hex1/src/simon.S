#define UART0_BASE              0x10000000
#define UART_LSR                5
#define LSR_RX_READY            1
#define BUFFER_SIZE             64

#define MAGIC_ADDRESS           0x100000
#define LABEL_TABLE_BASE        0x80090010
#define SHUTDOWN_SIG            0x5555
#define REBOOT_SIG              0x7777

#define PROC_STATE_UNUSED       0x0000
#define PROC_STATE_RUNNING      0xffff

#define NEWLINE                 0xA
#define HASH                    0x23
#define SEMICOLON               0x3B
#define F_LOWERCASE             0x66
#define F_UPPERCASE             0x46
#define A_LOWERCASE             0x61
#define A_UPPERCASE             0x41
#define DIGIT_9                 0x39
#define DIGIT_0                 0x30

.section .text
.global _start

/* -----------------------------------------------------------------------
    Memory Map (RISC-V 64-bit)

               < 0x80010000 : boot  - stage 1
    0x80010000 - 0x8004FFFF : simon - stage 2
    0x80050000 - 0x8006ffff : process descriptors (max 16, 4 KB each)
                                offset  len     description
                                0x000   0x008   PID
                                0x008   0x008   process state
                                0x010   0x008   sp
                                0x018   0x058   registers
                                0x070   0x001   forked?
                                0x071   0x008   child exit code
                                0x079   0x007   unused
                                0x080   0x008   name
                                0x088   0xf78   stack
    0x80070000 - 0x8007ffff : file names (max 64, 1 KB each)
    0x80080000 - 0x8008ffff : stdin device buffer
    0x80090000 - 0x8009000f : stdin disk locator    
                                    { logical sector (4 bytes), offset (2 bytes) }
    0x80090010 - 0x8009ffff : unused
    0x80100000 - 0x801003ff : file descriptor
                                    { address, length }
    0x80100400 - ???        : files
----------------------------------------------------------------------- */

# a0 - pointer, where boot stopped compiling

_start:
    la t0, script_ptr
    sd a0, 0(t0)

    la t0, file_ptr
    li t1, 0x80100400
    sd t1, 0(t0)

    auipc sp, 0
    li t0, 0x100000
    add sp, sp, t0

    la t0, next_file_data
    li t1, 0x80100000
    sd t1, 0(t0)

    la a0, greetings
    call puts
    

# =====================================================


sish:
    la t0, script_ptr
    ld t1, 0(t0)
sish_loop:
    li t0, 0
    lb t0, 0(t1)
    beqz t0, sish_init

    mv a0, t1
    la a1, str_src
    call cmdcmp
    bnez a0, sish_init

    addi t1, t1, 4
    call free_slot_file_name
    li t2, 0x0A
copy_name_loop:
    lb t3, 0(t1)
    beq t3, t2, skip_file_loop_head

    sb t3, 0(a0)

    addi a0, a0, 1
    addi t1, t1, 1
    j copy_name_loop
skip_file_loop_head:
    addi t1, t1, 1
    mv t4, t1
    li t5, 0
skip_file_loop:
    lb t3, 0(t1)
    beqz t3, skip_file_loop_done

    addi t5, t5, 1
    addi t1, t1, 1
    j skip_file_loop
skip_file_loop_done:
    li s1, 0x10
    mul s1, s1, a1
    li s2, 0x80100000
    add s2, s2, s1

    sd t4, 0(s2)
    sd t5, 8(s2)

    addi t1, t1, 1
    j sish_loop

sish_init:
    la a0, cmd_prefix
    call puts

    la s1, buffer
    li s2, 0

input_loop:
    call getc

    li t0, '\n'
    beq a0, t0, output
    li t0, '\r'
    beq a0, t0, output

    li t0, BUFFER_SIZE
    bge s2, t0, input_loop

    # Echo-вывод символа
    call putc

    # Запись в буфер по адресу
    sb a0, 0(s1)
    addi s1, s1, 1
    addi s2, s2, 1

    j input_loop
output:
    sb zero, 0(s1)
    la a0, sym_newline
    call puts
    
    # Проверки на команды -----------------------------
    # shutdown
    la a0, buffer
    la a1, shutdown_cmd
    call cmdcmp
    beqz a0, shutdown

    # reboot
    la a0, buffer 
    la a1, reboot_cmd
    call cmdcmp
    beqz a0, reboot

    # debug - для проверки отдельных элементов кода, в нашем случае kernel panic
    la a0, buffer
    la a1, debug_cmd
    call cmdcmp
    beqz a0, debug

    la a0, buffer
    la a1, ls_cmd
    call cmdcmp
    beqz a0, ls

    la a0, buffer
    la a1, hex0_cmd
    call cmdcmp
    beqz a0, hex0

    la a0, buffer
    la a1, do_cmd
    call cmdcmp
    beqz a0, do

    la a0, buffer
    la a1, hex1_cmd
    call cmdcmp
    beqz a0, hex1
    # -------------------------------------------------
    
    la a0, echo_cmd
    call puts
    la a0, buffer
    call puts

output_done:
    la a0, buffer
    li a1, 0
    li a2, BUFFER_SIZE
    call memset

    j sish_init


# ================= РЕАЛИЗАЦИЯ КОМАНД =================

# Команда shutdown
# 0x100000 - адрес для исполнения магических команд в зависимости от значения
shutdown:    
    li t0, MAGIC_ADDRESS
    li t1, SHUTDOWN_SIG
    sw t1, 0(t0)
    
    # если трюк не сработал - уходим в бесконечный цикл и наслаждаемся своей беспомощностью
    j shutdown

# Команда reboot
reboot:
    li t0, MAGIC_ADDRESS
    li t1, REBOOT_SIG
    sw t1, 0(t0)
    
    # если не сработало, пытаемся просто выключить
    j shutdown 



debug:
    j debug



ls:
    li t0, 0x80070000
    li t1, 0x8007ffff
    li t2, 0x3ff
ls_loop:
    bge t0, t1, ls_done

    lb a0, 0(t0)
    beqz a0, ls_loop_skip

    mv a0, t0
    call puts 
    la a0, sym_newline
    call puts
ls_loop_skip:
    add t0, t0, t2
    j ls_loop
ls_done:
    j output_done



hex0:
    la s1, buffer
    addi s1, s1, 5

    li t0, 0x80070000
    li t1, 0x8007ffff
    li t2, 0x3ff
    li t3, 0

hex0_find_file:
    bge t0, t1, hex0_done

    lb a0, 0(s1)
    beqz a0, hex0_done

    mv a0, t0
    mv a1, s1
    call strcmp
    beqz a0, hex0_file_founded

    addi t3, t3, 1
    add t0, t0, t2
    j hex0_find_file
hex0_file_founded:
    mv t1, t3
    li t2, 0x80100000
    li t3, 0x10
    mul t1, t1, t3
    add t1, t1, t2

    la a0, hex0_build
    call puts
    mv a0, t0
    call puts

    call free_slot_file_name
    mv t2, a1 
    mv t3, a0

    mv a0, t0
    call strlen

    mv t4, a0
    mv a2, a0
    mv a1, t3
    mv a0, t0
    call memcpy

    add t3, t3, t4
    li t4, 0x2e
    sb t4, 0(t3)
    li t4, 0x62
    sb t4, 1(t3)
    li t4, 0x69
    sb t4, 2(t3)
    li t4, 0x6e
    sb t4, 3(t3)

    ld t4, 0(t1)
    ld t5, 8(t1)

    la t0, file_ptr
    ld t1, 0(t0)

    li t0, 0x10
    mul t2, t2, t0
    li t0, 0x80100000
    add t2, t2, t0

    # t1 - file pointer
    # t2 - address to new descriptor
    # t3 - address to new name
    # t4 - address to src file
    # t5 - src file length

    sd t1, 0(t2)

    mv s1, t4
    li s3, 0
    mv s5, t1
    li t6, 0

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
                    addi t6, t6, 1
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
            sd t6, 8(t2)

            la a0, sym_newline
            call puts
            la a0, hex0_builded
            call puts
    
hex0_done:
    j output_done



do:
    la s1, buffer
    addi s1, s1, 3

    li t0, 0x80070000
    li t1, 0x8007ffff
    li t2, 0x3ff
    li t3, 0
do_find_file:
    bge t0, t1, do_done

    mv a0, t0
    mv a1, s1
    call strcmp
    beqz a0, do_file_founded

    addi t3, t3, 1
    add t0, t0, t2
    j do_find_file
do_file_founded:
    mv t1, t3
    li t2, 0x80100000
    li t3, 0x10
    mul t1, t1, t3
    add t1, t1, t2

    ld t0, 0(t1)

    jalr zero, (t0) 
do_done:
    j output_done



hex1:
    la s1, buffer
    addi s1, s1, 5

    li t0, 0x80070000
    li t1, 0x8007ffff
    li t2, 0x3ff
    li t3, 0

hex1_find_file:
    bge t0, t1, hex1_done
    lb a0, 0(s1)
    beqz a0, hex1_done
    mv a0, t0
    mv a1, s1
    call strcmp
    beqz a0, hex1_file_found
    addi t3, t3, 1
    add t0, t0, t2
    j hex1_find_file

hex1_file_found:
    mv t1, t3
    li t2, 0x10
    mul t1, t1, t2
    li t2, 0x80100000
    add t1, t1, t2

    la a0, hex0_build
    call puts
    mv a0, t0
    call puts

    call free_slot_file_name
    mv t2, a1
    mv t3, a0

    mv a0, t0
    call strlen
    mv t4, a0
    mv a2, a0
    mv a1, t3
    mv a0, t0
    call memcpy
    add t3, t3, t4
    li t4, 0x2e
    sb t4, 0(t3)
    li t4, 0x62
    sb t4, 1(t3)
    li t4, 0x69
    sb t4, 2(t3)
    li t4, 0x6e
    sb t4, 3(t3)

    ld t4, 0(t1)
    mv s8, t4

    li t0, 0x10
    mul t0, t0, t2
    li t5, 0x80100000
    add s9, t0, t5

    la t0, file_ptr
    ld t1, 0(t0)
    mv s7, t1
    sd s7, 0(s9)

    li t0, LABEL_TABLE_BASE
    sd zero, 0(t0)

    # PASS 1: обход источника, сбор меток, подсчёт байт
    mv s1, s8
    li s3, 0
    li s5, 0

hex1_p1:
    lb s2, 0(s1)
    addi s1, s1, 1
    beqz s2, hex1_p1_done

    li t0, HASH
    beq s2, t0, hex1_p1_comment
    li t0, SEMICOLON
    beq s2, t0, hex1_p1_comment
    li t0, 0x3A
    beq s2, t0, hex1_p1_label
    li t0, 0x25
    beq s2, t0, hex1_p1_ref

    li t0, (F_LOWERCASE + 1)
    bge s2, t0, hex1_p1
    li t0, A_LOWERCASE
    bge s2, t0, hex1_p1_nib
    li t0, (F_UPPERCASE + 1)
    bge s2, t0, hex1_p1
    li t0, A_UPPERCASE
    bge s2, t0, hex1_p1_nib
    li t0, (DIGIT_9 + 1)
    bge s2, t0, hex1_p1
    li t0, DIGIT_0
    bge s2, t0, hex1_p1_nib
    j hex1_p1

hex1_p1_nib:
    beqz s3, hex1_p1_flag1
    addi s5, s5, 1
    li s3, 0
    j hex1_p1
hex1_p1_flag1:
    li s3, 1
    j hex1_p1

hex1_p1_comment:
    lb t0, 0(s1)
    addi s1, s1, 1
    beqz t0, hex1_p1_done
    li t1, NEWLINE
    bne t0, t1, hex1_p1_comment
    j hex1_p1

hex1_p1_label:
    li t0, LABEL_TABLE_BASE
    ld t1, 0(t0)
    li t2, 16
    mul t2, t2, t1
    addi t2, t2, 8
    add t2, t0, t2
    sd s1, 0(t2)
    sd s5, 8(t2)
    addi t1, t1, 1
    sd t1, 0(t0)
    j hex1_p1_skip

hex1_p1_ref:
    addi s5, s5, 4
hex1_p1_skip:
    lb t0, 0(s1)
    beqz t0, hex1_p1_done
    li t1, NEWLINE
    beq t0, t1, hex1_p1
    li t1, 0x0D
    beq t0, t1, hex1_p1
    li t1, 0x20
    beq t0, t1, hex1_p1
    li t1, 0x09
    beq t0, t1, hex1_p1
    addi s1, s1, 1
    j hex1_p1_skip

hex1_p1_done:

    # PASS 2: генерация байт, подстановка адресов меток
    mv s1, s8
    mv s5, s7
    li s3, 0
    li s4, 0

hex1_p2:
    lb s2, 0(s1)
    addi s1, s1, 1
    beqz s2, hex1_p2_done

    li t0, HASH
    beq s2, t0, hex1_p2_comment
    li t0, SEMICOLON
    beq s2, t0, hex1_p2_comment
    li t0, 0x3A
    beq s2, t0, hex1_p2_skip
    li t0, 0x25
    beq s2, t0, hex1_p2_ref

    li t0, (F_LOWERCASE + 1)
    bge s2, t0, hex1_p2
    li t0, A_LOWERCASE
    bge s2, t0, hex1_p2_lo
    li t0, (F_UPPERCASE + 1)
    bge s2, t0, hex1_p2
    li t0, A_UPPERCASE
    bge s2, t0, hex1_p2_hi
    li t0, (DIGIT_9 + 1)
    bge s2, t0, hex1_p2
    li t0, DIGIT_0
    bge s2, t0, hex1_p2_dig
    j hex1_p2

hex1_p2_lo:
    addi s2, s2, -(A_LOWERCASE - 10)
    j hex1_p2_nibble
hex1_p2_hi:
    addi s2, s2, -(A_UPPERCASE - 10)
    j hex1_p2_nibble
hex1_p2_dig:
    addi s2, s2, -(DIGIT_0)
hex1_p2_nibble:
    slli s4, s4, 4
    andi s4, s4, 0xFF
    add s4, s4, s2
    beqz s3, hex1_p2_flag2
    sb s4, 0(s5)
    addi s5, s5, 1
    li s3, 0
    j hex1_p2
hex1_p2_flag2:
    li s3, 1
    j hex1_p2

hex1_p2_comment:
    lb t0, 0(s1)
    addi s1, s1, 1
    beqz t0, hex1_p2_done
    li t1, NEWLINE
    bne t0, t1, hex1_p2_comment
    j hex1_p2

hex1_p2_skip:
    lb t0, 0(s1)
    beqz t0, hex1_p2_done
    li t1, NEWLINE
    beq t0, t1, hex1_p2
    li t1, 0x0D
    beq t0, t1, hex1_p2
    li t1, 0x20
    beq t0, t1, hex1_p2
    li t1, 0x09
    beq t0, t1, hex1_p2
    addi s1, s1, 1
    j hex1_p2_skip

hex1_p2_ref:
    call hex1_lookup
    sub a0, a0, s5
    addi a0, a0, -4
    sb a0, 0(s5)
    srli t0, a0, 8
    sb t0, 1(s5)
    srli t0, a0, 16
    sb t0, 2(s5)
    srli t0, a0, 24
    sb t0, 3(s5)
    addi s5, s5, 4
    j hex1_p2

hex1_p2_done:
    sub t0, s5, s7
    sd t0, 8(s9)

    la t0, file_ptr
    sd s5, 0(t0)

    la a0, sym_newline
    call puts
    la a0, hex0_builded
    call puts

hex1_done:
    j output_done


/*
    Поиск метки в таблице по имени

    Вход: s1 = указатель на имя в исходнике (первый символ после %)
          s7 = базовый адрес выходного буфера
    Выход: a0 = абсолютный адрес метки (s7 + смещение), s1 сдвинут за имя
    Использует: t0-t6, a0, a1
*/

hex1_lookup:
    addi sp, sp, -16
    sd ra, 0(sp)

    mv t4, s1
hex1_lk_scan:
    lb t6, 0(t4)
    beqz t6, hex1_lk_scan_done
    li t0, 0x20
    beq t6, t0, hex1_lk_scan_done
    li t0, NEWLINE
    beq t6, t0, hex1_lk_scan_done
    li t0, 0x09
    beq t6, t0, hex1_lk_scan_done
    li t0, 0x0D
    beq t6, t0, hex1_lk_scan_done
    addi t4, t4, 1
    j hex1_lk_scan
hex1_lk_scan_done:
    sub t3, t4, s1
    sd t4, 8(sp)

    li t0, LABEL_TABLE_BASE
    ld t1, 0(t0)
    addi t0, t0, 8
    li t2, 0

hex1_lk_loop:
    beq t2, t1, hex1_lk_nf
    ld t5, 0(t0)
    mv t6, t3
    mv t4, s1

hex1_lk_cmp:
    beqz t6, hex1_lk_check
    lb a0, 0(t5)
    lb a1, 0(t4)
    bne a0, a1, hex1_lk_next
    addi t5, t5, 1
    addi t4, t4, 1
    addi t6, t6, -1
    j hex1_lk_cmp

hex1_lk_check:
    lb a0, 0(t5)
    beqz a0, hex1_lk_found
    li a1, 0x20
    beq a0, a1, hex1_lk_found
    li a1, NEWLINE
    beq a0, a1, hex1_lk_found
    li a1, 0x09
    beq a0, a1, hex1_lk_found
    li a1, 0x0D
    beq a0, a1, hex1_lk_found

hex1_lk_next:
    addi t0, t0, 16
    addi t2, t2, 1
    j hex1_lk_loop

hex1_lk_found:
    ld a0, 8(t0)
    add a0, a0, s7
    ld ra, 0(sp)
    ld t4, 8(sp)
    addi sp, sp, 16
    mv s1, t4
    ret

hex1_lk_nf:
    li a0, 0
    ld ra, 0(sp)
    ld t4, 8(sp)
    addi sp, sp, 16
    mv s1, t4
    ret

# =====================================================



# ====================== УТИЛИТЫ ======================

# Kernel panic
# a0 - адрес на вид ошибки
kernel_panic:
    mv t0, a0 
    la a0, msg_kernel_panic
    call puts
    mv a0, t0
    call puts 

    la a0, rec_kernel_panic_0
    call puts
    la a0, rec_kernel_panic_1
    call puts
kernel_panic_loop: 
    call getc 

    li t0, 'r'
    beq a0, t0, reboot
    li t0, 's'
    beq a0, t0, shutdown

    j kernel_panic_loop

/*
    Длина строки

    Аргументы:
    a0 - адрес на строку

    Вывод:
    a0 - кол-во символов до нулевого символа
*/
strlen:
    addi sp, sp, -16
    sd t0, 0(sp)
    sd t1, 8(sp)

    li t0, 0
strlen_loop:
    lb t1, 0(a0)
    beqz t1, strlen_done

    addi t0, t0, 1
    addi a0, a0, 1

    j strlen_loop
strlen_done:
    mv a0, t0

    ld t0, 0(sp)
    ld t1, 8(sp)
    addi sp, sp, 16
    ret

/*
    Сравнение строк (нормальная версия)

    Аргументы:
    a0 - адрес на строку
    a1 - адрес на строку

    Вывод:
    a0 - 0 если строки одинаковы, иначе 1
*/
strcmp:
    addi sp, sp, -24
    sd t0, 0(sp)
    sd t1, 8(sp)
    sd t2, 16(sp)
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
    ld t0, 0(sp)
    ld t1, 8(sp)
    ld t2, 16(sp)
    addi sp, sp, -24
    ret
strcmp_not_equal:
    li a0, 1
    ld t0, 0(sp)
    ld t1, 8(sp)
    ld t2, 16(sp)
    addi sp, sp, -24
    ret


/*  
    Сравнение строк (версия для команд)
    
    Аргументы:
    a0 - адрес на строку
    a1 - адрес на строку

    Вывод:
    a0 - 0 если строки одинаковы, иначе 1

    (!!!) строки считаются одинаковыми, если функция 
    дошла до нулевого символа строки в адресе a1, т. е.:
    a0: some text blablabla\0
    a1: some text\0
    считаются одинаковыми строками
*/
cmdcmp:
    addi sp, sp, -16
    sd t0, 0(sp)
    sd t1, 8(sp)
cmdcmp_loop:
    lb t0, 0(a0)
    lb t1, 0(a1)
    
    beqz t1, cmdcmp_equal
    bne t0, t1, cmdcmp_not_equal 
    
    addi a0, a0, 1
    addi a1, a1, 1
    j cmdcmp_loop
cmdcmp_equal:
    li a0, 0
    ld t0, 0(sp)
    ld t1, 8(sp)
    addi sp, sp, 16
    ret
cmdcmp_not_equal:
    li a0, 1
    ld t0, 0(sp)
    ld t1, 8(sp)
    addi sp, sp, 16
    ret


/*
    Заполнение блока памяти заданным значением

    Аргументы:
    a0 - адрес на ячейку памяти
    a1 - значение
    a2 - количество ячеек

    Вывод: 
    - 
*/
memset:
memset_loop:
    beqz a2, memset_done

    sb a1, 0(a0)
    addi a0, a0, 1
    addi a2, a2, -1

    j memset_loop
memset_done:
    ret


/*
    Копирование блока памяти из (1) адреса во (2)

    Аргументы:
    a0 - адрес (1)
    a1 - адрес (2)
    a2 - кол-во ячеек для копирования

    Вывод:
    -
*/
memcpy:
    addi sp, sp, -8
    sd t0, 0(sp)
memcpy_loop:
    beqz a2, memcpy_done

    lb t0, 0(a0)
    sb t0, 0(a1)

    addi a0, a0, 1
    addi a1, a1, 1
    addi a2, a2, -1

    j memcpy_loop
memcpy_done:
    ld t0, 0(sp)
    addi sp, sp, 8
    ret 


free_slot_file_name:
    addi sp, sp, -8
    sd t0, 0(sp)

    li a0, 0x80070000
    li a1, 0
free_slot_file_name_loop:
    lb t0, 0(a0)
    beqz t0, free_slot_file_name_found

    li t0, 0x3ff
    add a0, a0, t0
    addi a1, a1, 1
    j free_slot_file_name_loop
free_slot_file_name_found:
    ld t0, 0(sp)
    addi sp, sp, 8
    ret 


create_process:
    li t0, 0x80050000
    li t1, 16
    li t2, 0

create_process_loop:
    beq t2, t1, create_process_no_slot

    ld t3, 0x008(t0)
    beqz t3, create_process_slot_found

    addi t2, t2, 1
    li t3, 0x1000
    add t0, t0, t3
    j create_process_loop
create_process_no_slot:
    la a0, msg_kernel_panic_3
    call kernel_panic
create_process_slot_found:
    mv t1, t2
    sd t1, 0x000(t0)

    li t2, PROC_STATE_RUNNING
    sd t2, 0x008(t0)

    li t3, 0xfff
    add t3, t0, t3
    addi t3, t3, -104 
    sd a0,   0(t3)      # ra = pc 
    sd zero, 8(t3)      # s0
    sd zero, 16(t3)     # s1
    sd zero, 24(t3)     # s2
    sd zero, 32(t3)     # s3
    sd zero, 40(t3)     # s4
    sd zero, 48(t3)     # s5
    sd zero, 56(t3)     # s6
    sd zero, 64(t3)     # s7
    sd zero, 72(t3)     # s8
    sd zero, 80(t3)     # s9
    sd zero, 88(t3)     # s10
    sd zero, 96(t3)     # s11

    sd t3, 0x010(t0)

    li t2, 0
    sb t2, 0x070(t0)

    sd a1, 0x080(t0)
    ret


switch_context:
    addi sp, sp, -104 # ага...
    sd ra, 0(sp)
    sd s0, 8(sp)
    sd s1, 16(sp)
    sd s2, 24(sp)
    sd s3, 32(sp)
    sd s4, 40(sp)
    sd s5, 48(sp)
    sd s6, 56(sp)
    sd s7, 64(sp)
    sd s8, 72(sp)
    sd s9, 80(sp)
    sd s10, 88(sp)
    sd s11, 96(sp)

    sd sp, 0x010(a0)
    ld sp, 0x010(a1)

    la t0, current_proc
    sd a1, 0(t0)

    ld ra, 0(sp)
    ld s0, 8(sp)
    ld s1, 16(sp)
    ld s2, 24(sp)
    ld s3, 32(sp)
    ld s4, 40(sp)
    ld s5, 48(sp)
    ld s6, 56(sp)
    ld s7, 64(sp)
    ld s8, 72(sp)
    ld s9, 80(sp)
    ld s10, 88(sp)
    ld s11, 96(sp)
    addi sp, sp, 104
    ret


# put char
putc:
    addi sp, sp, -8
    sd t0, 0(sp)

    li t0, UART0_BASE
    sb a0, 0(t0)

    ld t0, 0(sp)
    addi sp, sp, 8
    ret


# get char
getc:
    addi sp, sp, -16
    sd t0, 0(sp)
    sd t1, 8(sp)

    li t0, UART0_BASE
1:
    lb t1, UART_LSR(t0)
    andi t1, t1, LSR_RX_READY
    beqz t1, 1b
    lb a0, 0(t0)

    ld t0, 0(sp)
    ld t1, 8(sp)
    addi sp, sp, 16
    ret


# put string
puts:
    addi sp, sp, -16
    sd t1, 0(sp)
    sd t2, 8(sp)

    mv t1, a0
    li t2, UART0_BASE
puts_loop:
    lb a0, (t1)
    beqz a0, puts_done
    sb a0, 0(t2)
    addi t1, t1, 1
    j puts_loop
puts_done:

    ld t1, 0(sp)
    ld t2, 8(sp)
    addi sp, sp, 16
    ret


# put hex
puth:
    addi sp, sp, -32
    sd s0, 0(sp)
    sd s1, 8(sp)
    sd t0, 16(sp)
    sd ra, 24(sp)
    
    mv s0, a0
    li s1, 16

    la a0, sym_hexnum
    call puts
puth_loop:
    srli a0, s0, 60
    andi a0, a0, 0xF

    li t0, 10
    blt a0, t0, puth_digit
    addi a0, a0, 87 # сделал буквы маленькими, чтобы в глазах не рябило
    j puth_output
puth_digit:
    addi a0, a0, 48
puth_output:
    call putc
    
    slli s0, s0, 4
    
    addi s1, s1, -1
    bnez s1, puth_loop
    
puth_done:
    ld ra, 24(sp)
    ld t0, 16(sp)
    ld s1, 8(sp)
    ld s0, 0(sp)
    addi sp, sp, 32
    ret

# =============== Вспомогательное ===============
cmd_prefix:             .string "\n\rSimon says~: "
echo_cmd:               .string "echo answered " # <- сделал не в совсем привычном виде, к командам не отношу

sym_newline:            .string "\r\n"
sym_space:              .string " "
sym_hexnum:             .string "0x"
str_src:                .string "src"
greetings:              .string "[BOOTED]: Stage 2 (simon) - coded by Team 42."
hex0_build:             .string "Building "
hex0_builded:           .string "Done."
# ===============================================

# =================== Команды ===================
debug_cmd:              .string "debug"
shutdown_cmd:           .string "shutdown"
reboot_cmd:             .string "reboot"
ls_cmd:                 .string "ls"
hex0_cmd:               .string "hex0"
do_cmd:                 .string "do"
hex1_cmd:               .string "hex1"
# ===============================================

# ================= Для ошибок ==================
msg_kernel_panic:       .string "[KERNEL PANIC]: "

# err messages
msg_kernel_panic_0:     .string "Debug\r\n"
msg_kernel_panic_1:     .string "Buffer overflowed\r\n"
msg_kernel_panic_2:     .string "Out of memory\r\n"
msg_kernel_panic_3:     .string "No free process slots\r\n"
msg_kernel_panic_4:     .string "Where are all the processes?\r\n"

# recommendation message
rec_kernel_panic_0:     .string "Please, press r to reboot\r\n"
rec_kernel_panic_1:     .string "...or press s to shutdown.\r\n"
# ===============================================

script_ptr:             .space  8
file_ptr:               .space  8
next_file_data:         .space  8
buffer:                 .space  BUFFER_SIZE
current_proc:           .space  8
next_sector: