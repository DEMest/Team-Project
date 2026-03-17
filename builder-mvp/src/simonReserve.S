#define UART0_BASE              0x10000000
#define UART_LSR                5
#define LSR_RX_READY            1
#define BUFFER_SIZE             32

#define MAGIC_ADDRESS           0x100000
#define SHUTDOWN_SIG            0x5555
#define REBOOT_SIG              0x7777

#define FREE_RAM_POINTER_SIZE   8
#define FREE_RAM_START          0x81000000
#define FREE_RAM_END            0x87ffffff
#define PAGE_SIZE               8192 

#define PROC_MAX                8
#define PROC_PAGES              3

#define PROC_STATE_UNUSED       0x0000
#define PROC_STATE_RUNNING      0xffffffffffffffff # сюда можно запихать любое значение отличное от нуля, развлекайтесь

#define PROC_SHIFT_PID          0
#define PROC_SHIFT_STATE        8
#define PROC_SHIFT_SP_ADDR      16

#define PROC_STACK_SIZE         0x4000          

.global _start
.section .text

/*  (!!!) По поводу регистров

    A function using a preserved register must restore its original value before returning.
    A function using a non-preserved register must assume it’s changed by a function call.

    Saved registers (s*, preserved) - регистры для глобального хранения
    значений. Если по какой-то причине вам понадобился занятый регистр s,
    то сохраните его содержимое в стек и затем верните.

    Temporary registers (t*, non-preserved) - регистры для использования
    ВНУТРИ функций. 

    Function arguments (a*, non-preserved) - мы кладём последовательно 
    аргументы в регистры a0-a7 и возвращаем нужное значение в a0.


    ra - регистр, хранящий адрес возврата (по которому ret возвращается)
    sp - буквально stack pointer, тут всё понятно

    0x81000000 - 0x87ffffff: для страниц
*/


# Стартовая точка, мы тут один раз, можно запихать какой-нибудь init 
_start:
    la a0, greetings
    call puts
    
    la t0, free_ram_pointer
    li t1, FREE_RAM_START
    sd t1, 0(t0)

    li t0, 0
    li t1, PROC_MAX
init_loop:
    bge t0, t1, init_loop_done

    addi sp, sp, -16
    sd t0, 0(sp)
    sd t1, 8(sp)

    # по три страницы на процесс (мне лень сюда вставлять ещё один цикл)
    call alloc_page
    call alloc_page
    call alloc_page

    ld t0, 0(sp)
    ld t1, 8(sp)
    addi sp, sp, 16

    addi t0, t0, 1
    j init_loop
init_loop_done:
    la s4, test_a
    la s7, test_b
    

main_loop:
    la a0, sym_newline
    call puts
    la a0, cmd_prefix
    call puts

    la s1, buffer
    li s2, 0
    
# ====================== ВВОД =========================
input_loop:
    call getc

    # Стрелка вверх (блокировка)
    li t0, 27
    beq a0, t0, handle_escape

    li t0, 127    # backspace
    beq a0, t0, do_backspace
    li t0, '\n'

    beq a0, t0, process_input
    li t0, '\r'
    
    beq a0, t0, process_input

    li t0, BUFFER_SIZE
    bge s2, t0, input_loop

    # Echo-вывод символа
    call putc

    # Запись в буфер по адресу
    sb a0, 0(s1)
    addi s1, s1, 1
    addi s2, s2, 1

    j input_loop

handle_escape:
    call getc
    li t1, '['
    bne a0, t1, input_loop

    call getc
    li t1, 'A'
    beq a0, t1, esc_up
    # li t1, 'B'
    # beq a0, t1, esc_down
    # li t1, 'C'
    # beq a0, t1, esc_right
    # li t1, 'D'
    # beq a0, t1, esc_left

    j input_loop

esc_up:
    j input_loop

do_backspace:
    beqz s2, input_loop          # Если буфер пуст — не стираем
    addi s1, s1, -1              # Смещаем указатель назад
    addi s2, s2, -1              # Длина уменьшается

    li a0, 8                     # backspace
    call putc
    li a0, 32                    # space
    call putc
    li a0, 8                     # backspace
    call putc

    j input_loop
    
process_input:
    sb zero, 0(s1)

    j output
    
# =====================================================

# ====================== ВЫВОД ========================
output:
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
    # -------------------------------------------------
    
    la a0, echo_cmd
    call puts
    la a0, buffer
    call puts

    la a0, buffer
    li a1, 0
    li a2, BUFFER_SIZE
    call memset

    j main_loop

# =====================================================



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
    la a0, test_a
    call create_process

    la a0, test_b
    call create_process

    li t0, 0x81000000
    ld sp, PROC_SHIFT_SP_ADDR(t0)

    call test_a

test_a:
    la a0, debug_a
    call puts 
test_a_loop:
    li a0, 'A'
    call putc

    li a0, 0x81000000
    li a1, 0x81006000
    call switch_context

    j test_a_loop

test_b:
    la a0, debug_b
    call puts 
test_b_loop:
    li a0, 'B'
    call putc

    li a0, 0x81006000
    li a1, 0x81000000
    call switch_context

    j test_b_loop
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
    li t0, 0
strlen_loop:
    lb t1, 0(a0)
    beqz t1, strlen_done

    addi t0, t0, 1
    addi a0, a0, 1

    j strlen_loop
strlen_done:
    mv a0, t0
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
    ret
cmdcmp_not_equal:
    li a0, 1
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
memcpy_loop:
    beqz a2, memcpy_done

    lb t0, 0(a0)
    sb t0, 0(a1)

    addi a0, a0, 1
    addi a1, a1, 1
    addi a2, a2, -1

    j memcpy_loop
memcpy_done:
    ret 


alloc_page:
    addi sp, sp, -8
    sd ra, 0(sp)

    la a0, msg_kernel_panic_2
    li t0, FREE_RAM_END
    li t2, PAGE_SIZE

    la t3, free_ram_pointer
    ld t4, 0(t3)

    add t1, t4, t2
    bge t1, t0, kernel_panic

    mv a0, t4
    li a1, 0
    mv a2, t2
    call memset

    la a0, allocated_page_addr
    call puts
    mv a0, t4
    call puth

    li t2, PAGE_SIZE
    add t4, t4, t2

    sd t4, 0(t3)
    ld ra, 0(sp)
    addi sp, sp, 8
    ret 

/*
    Переключение между окружениями(?).
    Для процессов.

    Аргументы:
    a0 - предыдущий stack pointer
    a1 - следующий stack pointer

    Вывод:
    - 
*/
switch_context:
    addi sp, sp, -160 # ага...
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
    # я не знаю как сильно нам пригодится сохранение t*, но пусть будет
    sd t0, 104(sp)
    sd t1, 112(sp)
    sd t2, 120(sp)
    sd t3, 128(sp)
    sd t4, 136(sp)
    sd t5, 144(sp)
    sd t6, 152(sp)

    sd sp, PROC_SHIFT_SP_ADDR(a0)
    ld sp, PROC_SHIFT_SP_ADDR(a1)

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
    ld t0, 104(sp)
    ld t1, 112(sp)
    ld t2, 120(sp)
    ld t3, 128(sp)
    ld t4, 136(sp)
    ld t5, 144(sp)
    ld t6, 152(sp)
    addi sp, sp, 160
    ret

/*
    Создание процесса.

    Аргументы:
    a0 - program counter 

    Вывод:
    -
*/
create_process:
    li t0, PAGE_SIZE
    li t1, PROC_PAGES
    mul t0, t0, t1

    li t1, PROC_MAX
    li t2, 0

    # t0 - память на процесс (3 страницы)
    # t1 - макс. количество процессов
    # t2 - индекс процесса
create_process_loop:
    bge t2, t1, create_process_no_slot

    li t3, FREE_RAM_START
    mul t4, t2, t0
    add t3, t3, t4

    ld t4, PROC_SHIFT_STATE(t3)
    beqz t4, create_process_slot_found

    addi t2, t2, 1
    j create_process_loop
create_process_no_slot:
    la a0, msg_kernel_panic_3
    call kernel_panic
create_process_slot_found:
    # t0 - размер памяти
    # t1 - индекс
    # t2 - адрес на память процесса
    # t3 - sp процесса  
    mv t1, t2

    li t2, FREE_RAM_START
    mul t3, t0, t1
    add t2, t2, t3
    
    add t3, t2, t0
    addi t3, t3, -1

    addi t3, t3, -160 # ага х2...
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
    sd zero, 104(t3)    # t0
    sd zero, 112(t3)    # t1
    sd zero, 120(t3)    # t2
    sd zero, 128(t3)    # t3
    sd zero, 136(t3)    # t4
    sd zero, 144(t3)    # t5
    sd zero, 152(t3)    # t6

    sd t3, PROC_SHIFT_SP_ADDR(t2)   # sp
    
    addi t3, t1, 1
    sd t3, PROC_SHIFT_PID(t2)       # pid = i + 1

    li t3, PROC_STATE_RUNNING
    sd t3, PROC_SHIFT_STATE(t2)     # state = running

    ret

# get char
putc:
    li t0, UART0_BASE
    sb a0, 0(t0)
    ret


# put char
getc:
    li t0, UART0_BASE
1:
    lb t1, UART_LSR(t0)
    andi t1, t1, LSR_RX_READY
    beqz t1, 1b
    lb a0, 0(t0)
    ret


# put string
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


# put hex
puth:
    addi sp, sp, -24
    sd s0, 0(sp)
    sd s1, 8(sp)
    sd ra, 16(sp)
    
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
    ld ra, 16(sp)
    ld s1, 8(sp)
    ld s0, 0(sp)
    addi sp, sp, 24
    ret
# ===============================================

buffer:                 .space  BUFFER_SIZE
free_ram_pointer:       .space  FREE_RAM_POINTER_SIZE
echo_cmd:               .string "echo answered " # <- сделал не в совсем привычном виде, к командам не отношу

sym_newline:            .string "\r\n"
sym_space:              .string " "
sym_hexnum:             .string "0x"

# =================== Команды ===================
debug_cmd:              .string "debug"
shutdown_cmd:           .string "shutdown"
reboot_cmd:             .string "reboot"
# ===============================================

# =============== Вспомогательное ===============
greetings:              .string "[BOOTED]: Kernel coded by Team 42."
cmd_prefix:             .string "Simon says~: "
debug_a:                 .string "starting A\r\n"
debug_b:                 .string "starting B\r\n"

allocated_page_addr:    .string "\r\npage allocated: "
# ===============================================

# ================= Для ошибок ==================
msg_kernel_panic:       .string "[KERNEL PANIC]: "

# err messages
msg_kernel_panic_0:     .string "Debug\r\n"
msg_kernel_panic_1:     .string "Buffer overflowed\r\n"
msg_kernel_panic_2:     .string "Out of memory\r\n"
msg_kernel_panic_3:     .string "No free process slots\r\n"

# recommendation message
rec_kernel_panic_0:     .string "Please, press r to reboot\r\n"
rec_kernel_panic_1:     .string "...or press s to shutdown.\r\n"
# ===============================================