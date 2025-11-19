#define UART0_BASE      0x10000000
#define UART_LSR        5
#define LSR_RX_READY    1
#define BUFFER_SIZE     32

#define MAGIC_ADDRESS   0x100000
#define SHUTDOWN_SIG    0x5555
#define REBOOT_SIG      0x7777

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
*/


# Стартовая точка, мы тут один раз, можно запихать какой-нибудь init 
_start:
    la a0, greetings
    call puts

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

    li t0, 8    # backspace
    beq a0, t0, do_backspace
    li t0, '\n'
    beq a0, t0, process_input
    li t0, '\r'
    beq a0, t0, process_input

    call putc

    sb a0, 0(s1)
    addi s1, s1, 1
    addi s2, s2, 1

    # Проверка на переполнение
    li t0, BUFFER_SIZE
    blt s2, t0, input_loop

    # Если переполнение — кернел паник просто потому что 
    la a0, sym_newline
    call puts
    la a0, msg_kernel_panic_1
    call kernel_panic

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
    li a0, 0x3456789abcdef0
    call puth
    j main_loop
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
    addi sp, sp, -12
    sd s0, 0(sp)
    sd s1, 4(sp)
    sd ra, 8(sp)
    
    mv s0, a0
    li s1, 16

    la a0, sym_hexnum
    call puts
puth_loop:
    srli a0, s0, 60
    andi a0, a0, 0xF

    li t0, 10
    blt a0, t0, puth_digit
    addi a0, a0, 55
    j puth_output
puth_digit:
    addi a0, a0, 48
puth_output:
    call putc
    
    slli s0, s0, 4
    
    addi s1, s1, -1
    bnez s1, puth_loop
    
puth_done:
    ld ra, 8(sp)
    ld s1, 4(sp)
    ld s0, 0(sp)
    addi sp, sp, 12
    ret
# ===============================================



# Вспомогательные строки
buffer:                 .space  BUFFER_SIZE
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

# ===============================================

# ================= Для ошибок ==================
msg_kernel_panic:       .string "[KERNEL PANIC]: "

# err messages
msg_kernel_panic_0:     .string "Debug\r\n"
msg_kernel_panic_1:     .string "Buffer overflowed\r\n"

# recommendation message
rec_kernel_panic_0:     .string "Please, press r to reboot\r\n"
rec_kernel_panic_1:     .string "...or press s to shutdown.\r\n"
# ===============================================
