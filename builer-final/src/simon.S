#define UART0_BASE              0x10000000
#define UART_LSR                5
#define LSR_RX_READY            1
#define BUFFER_SIZE             64

#define MAGIC_ADDRESS           0x100000
#define SHUTDOWN_SIG            0x5555
#define REBOOT_SIG              0x7777

#define PROC_STATE_UNUSED       0x0000
#define PROC_STATE_RUNNING      0xffff

#define OPEN_FILES_BASE         0x80090100
#define OPEN_FILES_END          0x80090300
#define OPEN_FILE_SIZE          0x20
#define OPEN_FILE_MAX_FD        16
#define ARGS_BLOCK_BASE         0x80098000

#define SYS_OPENAT              56
#define SYS_LSEEK               62
#define SYS_READ                63
#define SYS_WRITE               64
#define SYS_EXIT                93
#define SYS_BRK                 214

#define MCAUSE_ECALL_M          11
#define MCAUSE_TIMER_M          0x8000000000000007

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
    Memory Map (RISC-V 64-bit, QEMU virt, RAM 0x80000000 - 0x88000000)

    0x80000000 - 0x8004ffff : boot (stage 1) + payload-исходники (hex0/hex1/M0)
                              boot читает исходники отсюда и компилирует simon
                              в зону 0x80080000 (см. PAYLOAD_OFFSET в boot.S)
    0x80050000 - 0x8006ffff : process descriptors (max 16, 4 KB each)
                                offset  len     description
                                0x000   0x008   PID
                                0x008   0x008   process state (0=UNUSED, 0xFFFF=RUNNING)
                                0x010   0x008   sp
                                0x018   0x008   ra
                                0x020   0x060   s0-s11
                                0x080   0x040   a0-a7
                                0x0c0   0x008   mepc (saved PC for trap return)
                                0x0c8   0x038   reserved
                                0x100   0x038   t0-t6 (saved on context switch)
                                0x0f0   0x008   name
                                0x0f8   0xf00   process stack
    0x80070000 - 0x8007ffff : file names (max 64, 1 KB each)
    0x80080000 - 0x8008ffff : simon (stage 2) - boot компилирует сюда (64 KB)
                              реальный размер simon.bin ~10 KB, остаток - запас
    0x80090000 - 0x800900ff : kernel stack zone (sp в trap handler = 0x80090000,
                              растёт вниз; не пересекается с simon-кодом ниже)
    0x80090100 - 0x800902ff : open files table (16 x 32 bytes)
                                offset  len     description
                                0x00    0x08    global_file_index
                                0x08    0x08    current_offset
                                0x10    0x01    flags (bit 0 = used, bit 1 = writable)
                                0x11    0x0f    padding
    0x80090300 - 0x80097fff : reserved/unused
    0x80098000 - 0x800980ff : process args block (256 B)
                                0x00    0x08    argc
                                0x08    0x08    argv[0] ptr
                                0x10    0x08    argv[1] ptr
                                0x18    0x08    argv[2] ptr
                                0x20    0x08    NULL terminator
                                0x28-0xff       argv strings
    0x80098100 - 0x8009ffff : reserved/unused
    0x80100000 - 0x801003ff : file descriptors (max 64, 16 B each)
                                offset  len     description
                                0x00    0x08    file address
                                0x08    0x08    file length
    0x80100400 - 0x83ffffff : files data (создаваемые/компилируемые файлы)
    0x84000000 - 0x87ffffff : user heap (sys_brk), 64 MB
----------------------------------------------------------------------- */

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

    la t0, heap_ptr
    li t1, 0x84000000
    sd t1, 0(t0)

    li t0, OPEN_FILES_BASE
    li t1, OPEN_FILES_END
init_oft_loop:
    bge t0, t1, init_oft_done
    sd zero, 0(t0)
    addi t0, t0, 8
    j init_oft_loop
init_oft_done:

    la t0, yield
    csrw mtvec, t0

    li t0, 0x200BFF8 
    ld t1, 0(t0)
    li t2, 1000000
    add t1, t1, t2
    li t0, 0x2004000
    sd t1, 0(t0) 

    li t0, 0x80
    csrs mie, t0 

    li t0, 0x8
    csrs mstatus, t0

    la a0, idle_proc
    la a1, ps_name_idle
    call create_process

    la a0, sish
    la a1, ps_name_sish
    call create_process
loop:
    j loop

idle_proc:
    la a0, msg_kernel_panic_4
    call kernel_panic
    
# =====================================================

sish:
    la a0, greetings
    call puts

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

input_loop:
    la t0, buffer_ready
    lb t1, 0(t0)
    bnez t1, output

    j input_loop
output:
    la a0, sym_newline
    call puts
    
    la a0, buffer
    la a1, shutdown_cmd
    call cmdcmp
    beqz a0, shutdown

    la a0, buffer 
    la a1, reboot_cmd
    call cmdcmp
    beqz a0, reboot

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
    la a1, view_cmd
    call cmdcmp
    beqz a0, view
    
    la a0, echo_cmd
    call puts
    la a0, buffer
    call puts

output_done:
    la a0, buffer
    li a1, 0
    li a2, BUFFER_SIZE
    call memset

    la t0, buffer_ready
    li t1, 0
    sb t1, 0(t0)

    la t0, buffer_index
    li t1, 0
    sb t1, 0(t0)

    j sish_init

# ================= РЕАЛИЗАЦИЯ КОМАНД =================

shutdown:    
    li t0, MAGIC_ADDRESS
    li t1, SHUTDOWN_SIG
    sw t1, 0(t0)
    
    j shutdown

reboot:
    li t0, MAGIC_ADDRESS
    li t1, REBOOT_SIG
    sw t1, 0(t0)
    
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

    li a0, -1
    li s7, 0
hex0_find_dot:
    bge s7, t4, hex0_find_dot_done

    add s6, t0, s7
    lb s6, 0(s6)
    li s8, 0x2e
    bne s6, s8, hex0_find_dot_skip
    mv a0, s7
hex0_find_dot_skip:
    addi s7, s7, 1
    j hex0_find_dot
hex0_find_dot_done:
    li s7, -1
    beq a0, s7, hex0_copy_full
    mv t4, a0
hex0_copy_full:

    mv a2, t4
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
    addi t1, t1, 3
    andi t1, t1, -4
    sd t1, 0(t0)

    li t0, 0x10
    mul t2, t2, t0
    li t0, 0x80100000
    add t2, t2, t0

    sd t1, 0(t2)

    mv s1, t4
    li s3, 0
    mv s5, t1
    li t6, 0

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

            la t0, file_ptr
            sd s5, 0(t0)

            la a0, sym_newline
            call puts
            la a0, hex0_builded
            call puts
    
hex0_done:
    j output_done

do:
    la s1, buffer
    addi s1, s1, 3

    li s2, ARGS_BLOCK_BASE
    addi s2, s2, 0x28
    li s3, ARGS_BLOCK_BASE
    addi s3, s3, 0x08
    li s4, 0

do_parse_loop:
    li t0, 3
    bge s4, t0, do_parse_done

    lb t0, 0(s1)
    beqz t0, do_parse_done

    sd s2, 0(s3)
    addi s3, s3, 8

do_copy_word:
    lb t0, 0(s1)
    beqz t0, do_word_end
    li t1, ' '
    beq t0, t1, do_word_end

    sb t0, 0(s2)
    addi s1, s1, 1
    addi s2, s2, 1
    j do_copy_word

do_word_end:
    sb zero, 0(s2)
    addi s2, s2, 1
    addi s4, s4, 1

    lb t0, 0(s1)
    beqz t0, do_parse_done
    addi s1, s1, 1
    j do_parse_loop

do_parse_done:
    beqz s4, do_done

    li t0, ARGS_BLOCK_BASE
    sd s4, 0(t0)
    sd zero, 0x20(t0)

    li t0, ARGS_BLOCK_BASE
    ld a0, 0x08(t0)
    call find_file_by_name

    li t1, -1
    beq a0, t1, do_done

    li t1, 0x10
    mul a0, a0, t1
    li t1, 0x80100000
    add a0, a0, t1
    ld a0, 0(a0)

    li t0, ARGS_BLOCK_BASE
    ld a1, 0x08(t0)

    li a2, ARGS_BLOCK_BASE

    la t0, user_running
    li t1, 1
    sd t1, 0(t0)

    call create_user_process
    la t0, user_proc
    sd a0, 0(t0)
do_wait:
    ld t0, 0x8(a0)
    bnez t0, do_wait

do_done:
    j output_done

view:
    la s1, buffer
    addi s1, s1, 5

    li t0, 0x80070000
    li t1, 0x8007ffff
    li t2, 0x3ff
    li t3, 0
view_find_file:
    bge t0, t1, view_done

    mv a0, t0
    mv a1, s1
    call strcmp
    beqz a0, view_file_founded

    addi t3, t3, 1
    add t0, t0, t2
    j view_find_file

view_file_founded:
    mv t1, t3
    li t2, 0x80100000
    li t3, 0x10
    mul t1, t1, t3
    add t1, t1, t2

    ld t4, 0(t1)
    ld t5, 8(t1)

    la a0, sym_newline
    call puts

    mv s2, t4
    mv s3, t5
view_print_loop:
    beqz s3, view_done

    lb a0, 0(s2)

    li t0, 0x0A
    bne a0, t0, view_print_byte
    li a0, 0x0D
    call putc
    li a0, 0x0A

view_print_byte:
    call putc

    addi s2, s2, 1
    addi s3, s3, -1
    j view_print_loop

view_done:
    j output_done

# =====================================================

# ====================== УТИЛИТЫ ======================
.align 4
yield:
    csrw mscratch, t0
    la t0, current_proc
    ld t0, 0(t0)
    beqz t0, yield_no_save

    sd sp, 0x10(t0)
    csrr t1, mepc
    sd t1, 0xc0(t0)
    sd ra, 0x18(t0)
    sd s0, 0x20(t0); sd s1, 0x28(t0); sd s2, 0x30(t0)
    sd s3, 0x38(t0); sd s4, 0x40(t0); sd s5, 0x48(t0)
    sd s6, 0x50(t0); sd s7, 0x58(t0); sd s8, 0x60(t0)
    sd s9, 0x68(t0); sd s10, 0x70(t0); sd s11, 0x78(t0)
    sd a0, 0x80(t0); sd a1, 0x88(t0); sd a2, 0x90(t0)
    sd a3, 0x98(t0); sd a4, 0xa0(t0); sd a5, 0xa8(t0)
    sd a6, 0xb0(t0); sd a7, 0xb8(t0)
    sd t1, 0x108(t0); sd t2, 0x110(t0); sd t3, 0x118(t0)
    sd t4, 0x120(t0); sd t5, 0x128(t0); sd t6, 0x130(t0)
    csrr t1, mscratch
    sd t1, 0x100(t0)

yield_no_save:
    csrr t6, mcause
    li t5, MCAUSE_ECALL_M
    beq t6, t5, syscall_entry

    li t5, MCAUSE_TIMER_M
    beq t6, t5, yield_timer

    j trap_panic

yield_timer:
    li t0, UART0_BASE
    lb t1, UART_LSR(t0)
    andi t1, t1, LSR_RX_READY
    beqz t1, yield_processes

    lb a0, 0(t0)

    li t2, '\n'
    beq a0, t2, yield_prepare_input

    li t2, '\r'
    beq a0, t2, yield_prepare_input

yield_regular_char:
    la t2, buffer_index
    lb t3, 0(t2)
    la t2, buffer
    add t2, t2, t3

    sb a0, 0(t2)
    addi t3, t3, 1
    la t2, buffer_index
    sb t3, 0(t2)

    sb a0, 0(t0)
    j yield_processes
yield_prepare_input:
    la t2, buffer_index
    lb t3, 0(t2)
    la t2, buffer
    add t2, t2, t3

    sb zero, 0(t2)
    addi t3, t3, 1
    la t2, buffer_index
    sb t3, 0(t2)

    li t2, 1
    la t3, buffer_ready
    sb t2, 0(t3)

yield_processes:
    la t0, user_running
    ld t0, 0(t0)
    beqz t0, find_next

    la t0, user_proc
    ld t0, 0(t0)
    beqz t0, find_next

    ld t1, 0x8(t0)
    beqz t1, find_next

    la t1, current_proc
    sd t0, 0(t1)

    li t1, 0x200BFF8
    ld t2, 0(t1)
    li t3, 1000000
    add t2, t2, t3
    li t1, 0x2004000
    sd t2, 0(t1)

    j resume_proc_context

syscall_entry:
    csrci mstatus, 0x8

    la t0, current_proc
    ld t0, 0(t0)
    beqz t0, syscall_no_proc

    sd sp, 0x10(t0)
    csrr t1, mepc
    addi t1, t1, 4
    sd t1, 0xc0(t0)

    sd ra, 0x18(t0)

    sd s0, 0x20(t0); sd s1, 0x28(t0); sd s2, 0x30(t0)
    sd s3, 0x38(t0); sd s4, 0x40(t0); sd s5, 0x48(t0)
    sd s6, 0x50(t0); sd s7, 0x58(t0); sd s8, 0x60(t0)
    sd s9, 0x68(t0); sd s10, 0x70(t0); sd s11, 0x78(t0)

    sd a0, 0x80(t0); sd a1, 0x88(t0); sd a2, 0x90(t0)
    sd a3, 0x98(t0); sd a4, 0xa0(t0); sd a5, 0xa8(t0)
    sd a6, 0xb0(t0); sd a7, 0xb8(t0)

    li sp, 0x80090000

    # === Диспетчер ===
    li t1, SYS_EXIT
    beq a7, t1, sys_exit

    li t1, SYS_WRITE
    beq a7, t1, sys_write

    li t1, SYS_READ
    beq a7, t1, sys_read

    li t1, SYS_OPENAT
    beq a7, t1, sys_openat

    li t1, SYS_LSEEK
    beq a7, t1, sys_lseek

    li t1, SYS_BRK
    beq a7, t1, sys_brk

    j syscall_return_minus_one

syscall_no_proc:
    la a0, msg_syscall_no_proc
    j kernel_panic

syscall_return_zero:
    la t0, current_proc
    ld t0, 0(t0)
    sd zero, 0x80(t0)
    j syscall_resume_current

syscall_return_minus_one:
    la t0, current_proc
    ld t0, 0(t0)
    li t1, -1
    sd t1, 0x80(t0)
    j syscall_resume_current

syscall_resume_current:
    la t0, current_proc
    ld t0, 0(t0)

    li t1, 0x200BFF8
    ld t2, 0(t1)
    li t3, 1000000
    add t2, t2, t3
    li t1, 0x2004000
    sd t2, 0(t1)

    ld t1, 0xc0(t0)
    csrw mepc, t1

    ld sp, 0x10(t0)
    ld ra, 0x18(t0)
    ld s0, 0x20(t0); ld s1, 0x28(t0); ld s2, 0x30(t0)
    ld s3, 0x38(t0); ld s4, 0x40(t0); ld s5, 0x48(t0)
    ld s6, 0x50(t0); ld s7, 0x58(t0); ld s8, 0x60(t0)
    ld s9, 0x68(t0); ld s10, 0x70(t0); ld s11, 0x78(t0)

    ld a0, 0x80(t0); ld a1, 0x88(t0); ld a2, 0x90(t0)
    ld a3, 0x98(t0); ld a4, 0xa0(t0); ld a5, 0xa8(t0)
    ld a6, 0xb0(t0); ld a7, 0xb8(t0)

    mret

/*
    Системный вызов exit (93)

    Аргументы:
    a0 - код возврата (игнорируем)

    Помечает процесс как UNUSED и снимает флаг user_running.
*/
sys_exit:
    la t0, current_proc
    ld t0, 0(t0)
    sd zero, 0x8(t0)

    la t1, user_running
    sd zero, 0(t1)

    li t1, OPEN_FILES_BASE
    li t2, OPEN_FILES_END
sys_exit_close_loop:
    bge t1, t2, sys_exit_close_done
    sd zero, 0(t1)
    sd zero, 8(t1)
    sd zero, 16(t1)
    sd zero, 24(t1)
    addi t1, t1, OPEN_FILE_SIZE
    j sys_exit_close_loop
sys_exit_close_done:

    la t1, current_proc
    sd zero, 0(t1)

    j find_next

/*
    Системный вызов write (64)

    Аргументы:
    a0 - файловый дескриптор (1/2 - stdout, >=3 - файл)
    a1 - адрес буфера
    a2 - количество байт

    Вывод:
    a0 - количество записанных байт
*/
sys_write:
    la t0, current_proc
    ld t0, 0(t0)
    ld t1, 0x80(t0)
    ld t2, 0x88(t0)
    ld t3, 0x90(t0)

    li t4, 1
    beq t1, t4, sys_write_stdout
    li t4, 2
    beq t1, t4, sys_write_stdout

    li t4, 3
    bge t1, t4, sys_write_file

    j syscall_return_minus_one

sys_write_stdout:
    li t4, UART0_BASE
    li t6, 0
sys_write_loop:
    beqz t3, sys_write_done

    lb t5, 0(t2)
    li a0, 0x0A
    bne t5, a0, sys_write_putc
    li a0, 0x0D
    sb a0, 0(t4)

sys_write_putc:
    sb t5, 0(t4)

    addi t2, t2, 1
    addi t3, t3, -1
    addi t6, t6, 1
    j sys_write_loop

sys_write_done:
    sd t6, 0x80(t0)
    j syscall_resume_current

/*
    Запись в открытый файл (вызывается из sys_write при fd >= 3)

    Аргументы:
    t1 - fd, t2 - буфер, t3 - количество байт
*/
sys_write_file:
    addi t1, t1, -3
    li t4, OPEN_FILE_SIZE
    mul t1, t1, t4
    li t4, OPEN_FILES_BASE
    add t1, t1, t4

    lb t4, 0x10(t1)
    andi t5, t4, 0x01
    beqz t5, syscall_return_minus_one
    andi t5, t4, 0x02
    beqz t5, syscall_return_minus_one

    ld t4, 0x00(t1)
    ld t5, 0x08(t1)

    li t6, 0x10
    mul t6, t4, t6
    li a3, 0x80100000
    add t6, t6, a3
    ld a3, 0(t6)
    ld a4, 8(t6)

    li a5, 0
sys_write_file_loop:
    beq a5, t3, sys_write_file_done

    lb a6, 0(t2)
    add a7, a3, t5
    sb a6, 0(a7)

    addi t5, t5, 1

    ble t5, a4, sys_write_file_no_grow
    mv a4, t5
    la a6, file_ptr
    ld a7, 0(a6)
    addi a7, a7, 1
    sd a7, 0(a6)
sys_write_file_no_grow:

    addi t2, t2, 1
    addi a5, a5, 1
    j sys_write_file_loop

sys_write_file_done:
    sd t5, 0x08(t1)
    sd a4, 8(t6)

    la t0, current_proc
    ld t0, 0(t0)
    sd a5, 0x80(t0)
    j syscall_resume_current

/*
    Системный вызов openat (56)

    Аргументы:
    a1 - имя файла (путь)
    a2 - флаги (0 = O_RDONLY, 0x241 = O_CREAT|O_WRONLY|O_TRUNC)

    Вывод:
    a0 - файловый дескриптор (>= 3) или -1 при ошибке
*/
sys_openat:
    la t0, current_proc
    ld t0, 0(t0)

    ld a0, 0x88(t0)
    ld t1, 0x90(t0)

    beqz t1, sys_openat_rdonly

    li t2, 0x241
    beq t1, t2, sys_openat_creat

    j syscall_return_minus_one

sys_openat_rdonly:
    call find_file_by_name
    li t1, -1
    beq a0, t1, syscall_return_minus_one

    addi sp, sp, -8
    sd a0, 0(sp)

    call alloc_open_file_slot
    li t1, -1
    beq a0, t1, syscall_openat_fail

    li t1, OPEN_FILE_SIZE
    mul t3, a0, t1
    li t1, OPEN_FILES_BASE
    add t3, t3, t1

    ld t2, 0(sp)
    addi sp, sp, 8

    sd t2, 0x00(t3)
    sd zero, 0x08(t3)
    li t1, 0x01
    sb t1, 0x10(t3)

    addi a0, a0, 3

    la t0, current_proc
    ld t0, 0(t0)
    sd a0, 0x80(t0)
    j syscall_resume_current

sys_openat_creat:
    addi sp, sp, -32
    sd a0, 0(sp)

    call find_file_by_name
    li t1, -1
    bne a0, t1, sys_openat_creat_existing

    call free_slot_file_name
    sd a1, 8(sp)

    mv t0, a0
    ld t1, 0(sp)
sys_openat_copy_name:
    lb t2, 0(t1)
    sb t2, 0(t0)
    beqz t2, sys_openat_copy_name_done
    addi t1, t1, 1
    addi t0, t0, 1
    j sys_openat_copy_name
sys_openat_copy_name_done:

    la t0, file_ptr
    ld t1, 0(t0)
    addi t1, t1, 3
    andi t1, t1, -4
    sd t1, 0(t0)

    ld t2, 8(sp)
    li t3, 0x10
    mul t3, t2, t3
    li t4, 0x80100000
    add t3, t3, t4

    sd t1, 0(t3)
    sd zero, 8(t3)

    j sys_openat_creat_open

sys_openat_creat_existing:
    sd a0, 8(sp)

    li t3, 0x10
    mul t3, a0, t3
    li t4, 0x80100000
    add t3, t3, t4
    sd zero, 8(t3)

sys_openat_creat_open:
    call alloc_open_file_slot
    li t1, -1
    beq a0, t1, sys_openat_creat_fail

    li t1, OPEN_FILE_SIZE
    mul t3, a0, t1
    li t1, OPEN_FILES_BASE
    add t3, t3, t1

    ld t2, 8(sp)
    sd t2, 0x00(t3)
    sd zero, 0x08(t3)
    li t1, 0x03
    sb t1, 0x10(t3)

    addi a0, a0, 3

    addi sp, sp, 32

    la t0, current_proc
    ld t0, 0(t0)
    sd a0, 0x80(t0)
    j syscall_resume_current

sys_openat_creat_fail:
    addi sp, sp, 32
    j syscall_return_minus_one

syscall_openat_fail:
    addi sp, sp, 8
    j syscall_return_minus_one

/*
    Системный вызов read (63)

    Аргументы:
    a0 - файловый дескриптор
    a1 - адрес буфера
    a2 - количество байт

    Вывод:
    a0 - количество прочитанных байт (0 = конец файла)
*/
sys_read:
    la t0, current_proc
    ld t0, 0(t0)
    ld t1, 0x80(t0)
    ld t2, 0x88(t0)
    ld t3, 0x90(t0)

    li t4, 3
    blt t1, t4, syscall_return_zero

    addi t1, t1, -3
    li t4, OPEN_FILE_SIZE
    mul t1, t1, t4
    li t4, OPEN_FILES_BASE
    add t1, t1, t4

    lb t4, 0x10(t1)
    andi t4, t4, 0x01
    beqz t4, syscall_return_minus_one

    ld t4, 0x00(t1)
    ld t5, 0x08(t1)

    li t6, 0x10
    mul t4, t4, t6
    li t6, 0x80100000
    add t4, t4, t6
    ld a3, 0x00(t4)
    ld a4, 0x08(t4)

    sub a5, a4, t5
    blez a5, sys_read_eof

    blt t3, a5, sys_read_count_ok
    mv t3, a5
sys_read_count_ok:
    add a3, a3, t5
    mv a4, t2
    mv a5, t3
    li a6, 0
sys_read_copy_loop:
    beq a6, a5, sys_read_copy_done
    lb a7, 0(a3)
    sb a7, 0(a4)
    addi a3, a3, 1
    addi a4, a4, 1
    addi a6, a6, 1
    j sys_read_copy_loop
sys_read_copy_done:

    add t5, t5, t3
    sd t5, 0x08(t1)

    sd t3, 0x80(t0)
    j syscall_resume_current

sys_read_eof:
    sd zero, 0x80(t0)
    j syscall_resume_current

/*
    Системный вызов lseek (62)

    Аргументы:
    a0 - файловый дескриптор
    a1 - смещение
    a2 - откуда (0 = SET, 1 = CUR, 2 = END)

    Вывод:
    a0 - новое смещение
*/
sys_lseek:
    la t0, current_proc
    ld t0, 0(t0)
    ld t1, 0x80(t0)
    ld t2, 0x88(t0)
    ld t3, 0x90(t0)

    li t4, 3
    blt t1, t4, syscall_return_minus_one

    addi t1, t1, -3
    li t4, OPEN_FILE_SIZE
    mul t1, t1, t4
    li t4, OPEN_FILES_BASE
    add t1, t1, t4

    lb t4, 0x10(t1)
    andi t4, t4, 0x01
    beqz t4, syscall_return_minus_one

    beqz t3, sys_lseek_set

    li t4, 1
    beq t3, t4, sys_lseek_cur

    li t4, 2
    beq t3, t4, sys_lseek_end

    j syscall_return_minus_one

sys_lseek_set:
    sd t2, 0x08(t1)
    sd t2, 0x80(t0)
    j syscall_resume_current

sys_lseek_cur:
    ld t4, 0x08(t1)
    add t2, t2, t4
    sd t2, 0x08(t1)
    sd t2, 0x80(t0)
    j syscall_resume_current

sys_lseek_end:
    ld t4, 0x00(t1)
    li t5, 0x10
    mul t4, t4, t5
    li t5, 0x80100000
    add t4, t4, t5
    ld t5, 0x08(t4)
    add t2, t2, t5
    sd t2, 0x08(t1)
    sd t2, 0x80(t0)
    j syscall_resume_current

/*
    Системный вызов brk (214)

    Аргументы:
    a0 - новое значение brk, или 0 для запроса текущего

    Вывод:
    a0 - текущее (или новое) значение конца кучи
*/
sys_brk:
    la t0, current_proc
    ld t0, 0(t0)
    ld t1, 0x80(t0)

    la t2, heap_ptr
    ld t3, 0(t2)

    beqz t1, sys_brk_return_current

    li t4, 0x84000000
    bltu t1, t4, sys_brk_return_current
    li t4, 0x88000000
    bgeu t1, t4, sys_brk_return_current

    sd t1, 0(t2)
    sd t1, 0x80(t0)
    j syscall_resume_current

sys_brk_return_current:
    sd t3, 0x80(t0)
    j syscall_resume_current

/*
    Поиск файла по имени в таблице имён

    Аргументы:
    a0 - адрес строки имени

    Вывод:
    a0 - индекс файла (0..63) или -1 если не найдено
*/
find_file_by_name:
    addi sp, sp, -32
    sd ra, 0(sp)
    sd s0, 8(sp)
    sd s1, 16(sp)
    sd s2, 24(sp)

    mv s0, a0
    li s1, 0x80070000
    li s2, 0
find_file_loop:
    li t0, 64
    bge s2, t0, find_file_not_found

    mv a0, s1
    mv a1, s0
    call strcmp
    beqz a0, find_file_found

    addi s2, s2, 1
    li t0, 0x3ff
    add s1, s1, t0
    j find_file_loop

find_file_found:
    mv a0, s2
    j find_file_return

find_file_not_found:
    li a0, -1

find_file_return:
    ld ra, 0(sp)
    ld s0, 8(sp)
    ld s1, 16(sp)
    ld s2, 24(sp)
    addi sp, sp, 32
    ret

alloc_open_file_slot:
    li t0, OPEN_FILES_BASE
    li t1, 0
alloc_open_file_loop:
    li t2, OPEN_FILE_MAX_FD
    bge t1, t2, alloc_open_file_full

    lb t3, 0x10(t0)
    andi t3, t3, 0x01
    beqz t3, alloc_open_file_done

    addi t1, t1, 1
    li t2, OPEN_FILE_SIZE
    add t0, t0, t2
    j alloc_open_file_loop

alloc_open_file_done:
    mv a0, t1
    ret

alloc_open_file_full:
    li a0, -1
    ret

find_next:
    la t0, current_proc
    ld t1, 0(t0)
    mv t2, t1 
    bnez t1, search_loop

    li t1, 0x80051000
    mv t2, t1
    sd t1, 0(t0)
search_loop:    
    li t3, 0x1000
    add t2, t2, t3
    li t4, 0x80070000
    beq t2, t4, search_loop_overflow

    ld t3, 0x8(t2)
    li t4, 0xffff
    beq t3, t4, found_task  

    j search_loop
search_loop_overflow:
    li t2, 0x80051000

    ld t3, 0x8(t2)
    li t4, 0xffff
    beq t3, t4, found_task

    j search_loop
search_loop_idle:    
    li t1, 0x80050000
    ld t3, 0x8(t1)
    li t4, 0xffff
    beq t3, t4, found_task
    
    la a0, msg_kernel_panic_4
    j kernel_panic

found_task:
    mv t1, t2
    la t0, current_proc
    sd t1, 0(t0)
    mv t0, t1

    li t1, 0x200BFF8
    ld t2, 0(t1)
    li t3, 1000000
    add t2, t2, t3
    li t1, 0x2004000
    sd t2, 0(t1)

resume_proc_context:
    ld t1, 0xc0(t0)
    csrw mepc, t1
    
    ld sp, 0x10(t0)
    ld ra, 0x18(t0)
    ld s0, 0x20(t0); ld s1, 0x28(t0); ld s2, 0x30(t0)
    ld s3, 0x38(t0); ld s4, 0x40(t0); ld s5, 0x48(t0)
    ld s6, 0x50(t0); ld s7, 0x58(t0); ld s8, 0x60(t0)
    ld s9, 0x68(t0); ld s10, 0x70(t0); ld s11, 0x78(t0)

    ld a0, 0x80(t0); ld a1, 0x88(t0); ld a2, 0x90(t0)
    ld a3, 0x98(t0); ld a4, 0xa0(t0); ld a5, 0xa8(t0)
    ld a6, 0xb0(t0); ld a7, 0xb8(t0)

    ld t1, 0x100(t0)
    csrw mscratch, t1
    ld t1, 0x108(t0); ld t2, 0x110(t0); ld t3, 0x118(t0)
    ld t4, 0x120(t0); ld t5, 0x128(t0); ld t6, 0x130(t0)

    csrr t0, mscratch
    mret

create_process:
    li t0, 0x80050000
    li t1, 0
    create_process_loop:
        li t2, 0x8006ffff
        bge t0, t2, create_process_no_slot

        ld t2, 0x8(t0)
        beqz t2, create_process_slot_found

        addi t1, t1, 1
        li t3, 0x1000
        add t0, t0, t3
        j create_process_loop
        create_process_no_slot:
            la a0, msg_kernel_panic_3
            call kernel_panic
        create_process_slot_found:
            sd t1, 0(t0)

            li t2, PROC_STATE_RUNNING
            sd t2, 0x8(t0)

            li t3, 0xff8
            add t2, t0, t3
            sd t2, 0x10(t0)

            sd a0, 0xc0(t0)
            sd zero, 0x18(t0)
            sd a1, 0xf0(t0)

            sd zero, 0x80(t0)
            sd zero, 0x88(t0)
            sd zero, 0x90(t0)
            sd zero, 0x98(t0)
            sd zero, 0xa0(t0)
            sd zero, 0xa8(t0)
            sd zero, 0xb0(t0)
            sd zero, 0xb8(t0)

            sd zero, 0x100(t0); sd zero, 0x108(t0); sd zero, 0x110(t0)
            sd zero, 0x118(t0); sd zero, 0x120(t0); sd zero, 0x128(t0)
            sd zero, 0x130(t0)

            mv a0, t0
            ret

create_user_process:
    addi sp, sp, -16
    sd ra, 0(sp)
    sd a2, 8(sp)

    call create_process

    ld t0, 8(sp)
    sd t0, 0x10(a0)

    ld ra, 0(sp)
    addi sp, sp, 16
    ret
            
switch_context:
    sd sp, 0x10(a0)
    sd ra, 0x18(a0)
    sd s0, 0x20(a0)
    sd s1, 0x28(a0)
    sd s2, 0x30(a0)
    sd s3, 0x38(a0)
    sd s4, 0x40(a0)
    sd s5, 0x48(a0)
    sd s6, 0x50(a0)
    sd s7, 0x58(a0)
    sd s8, 0x60(a0)
    sd s9, 0x68(a0)
    sd s10, 0x70(a0)
    sd s11, 0x78(a0)

    la t0, current_proc
    sd a1, 0(t0)

    ld sp, 0x10(a1)
    ld ra, 0x18(a1)
    ld s0, 0x20(a1)
    ld s1, 0x28(a1)
    ld s2, 0x30(a1)
    ld s3, 0x38(a1)
    ld s4, 0x40(a1)
    ld s5, 0x48(a1)
    ld s6, 0x50(a1)
    ld s7, 0x58(a1)
    ld s8, 0x60(a1)
    ld s9, 0x68(a1)
    ld s10, 0x70(a1)
    ld s11, 0x78(a1)
    ret

/*
    Обработка непредвиденного исключения (не ecall и не таймер)

    Печатает mcause, mepc, mtval и уходит в kernel_panic.
    Сюда мы попадаем из yield_no_save, когда trap случился по причине,
    которую мы не ждали: illegal instruction, access fault и прочая радость.

    Регистры процесса к этому моменту уже сохранены в начале yield,
    так что портить t* можно без зазрения совести.
*/
trap_panic:
    la a0, msg_trap_cause
    call puts
    csrr a0, mcause
    call puth
    la a0, sym_newline
    call puts

    la a0, msg_trap_mepc
    call puts
    csrr a0, mepc
    call puth
    la a0, sym_newline
    call puts

    la a0, msg_trap_mtval
    call puts
    csrr a0, mtval
    call puth
    la a0, sym_newline
    call puts

    la a0, msg_trap_panic
    j kernel_panic

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
            addi sp, sp, 24
            ret
        strcmp_not_equal:
            li a0, 1
            ld t0, 0(sp)
            ld t1, 8(sp)
            ld t2, 16(sp)
            addi sp, sp, 24
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

putc:
    addi sp, sp, -8
    sd t0, 0(sp)

    li t0, UART0_BASE
    sb a0, 0(t0)

    ld t0, 0(sp)
    addi sp, sp, 8
    ret

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
    addi a0, a0, 87
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

# ============= Сообщения исключений ============
msg_trap_cause:         .string "[TRAP] mcause = "
msg_trap_mepc:          .string "[TRAP] mepc   = "
msg_trap_mtval:         .string "[TRAP] mtval  = "
msg_trap_panic:         .string "Unhandled exception\r\n"
# ===============================================

# =================== Команды ===================
debug_cmd:              .string "debug"
shutdown_cmd:           .string "shutdown"
reboot_cmd:             .string "reboot"
ls_cmd:                 .string "ls"
hex0_cmd:               .string "hex0"
do_cmd:                 .string "do"
view_cmd:               .string "view"
# ===============================================

# ================== Процессы ===================
ps_name_undefined:      .string "undefined"
ps_name_idle:           .string "<init>"
ps_name_sish:           .string "SiSH" 
ps_name_debug:          .string "debug cmd"
# ===============================================

# ================= Для ошибок ==================
msg_kernel_panic:       .string "[KERNEL PANIC]: "

msg_kernel_panic_0:     .string "Debug\r\n"
msg_kernel_panic_1:     .string "Buffer overflowed\r\n"
msg_kernel_panic_2:     .string "Out of memory\r\n"
msg_kernel_panic_3:     .string "No free process slots\r\n"
msg_kernel_panic_4:     .string "Where are all the processes?\r\n"
msg_syscall_no_proc:    .string "Syscall without current process\r\n"

rec_kernel_panic_0:     .string "Please, press r to reboot\r\n"
rec_kernel_panic_1:     .string "...or press s to shutdown.\r\n"
# ===============================================

script_ptr:             .space  8
file_ptr:               .space  8
next_file_data:         .space  8
heap_ptr:               .space  8
user_running:           .space  8
user_proc:              .space  8
buffer:                 .space  BUFFER_SIZE
buffer_index:           .space  1
buffer_ready:           .space  1
current_proc:           .space  8
next_sector:
