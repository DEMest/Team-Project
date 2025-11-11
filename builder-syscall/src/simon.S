#define UART0_BASE      0x10000000
#define UART_LSR        5
#define LSR_RX_READY    1
#define BUFFER_SIZE     32

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
    la a0, cmd_prefix
    call puts

    la s1, buffer
    li s2, 0
    
# ====================== ВВОД =========================
input_loop:
    call getc # Ждём символ
    call putc # Эхо-вывод
    # !!! по хорошему бы как-то отдельно обрабатывать кнопку backspace, иначе начинается стендап с вводом
    # Upd 09.11.25: закидываю issue, иначе мы так и не исправим эту проблему 
    
    # Сохраняем символ в буфер
    sb a0, 0(s1)
    addi s1, s1, 1
    addi s2, s2, 1
    
    # Проверка на конец строки
    li t0, '\r' # я не знаю как можно ввести символ возврата каретки, но на всякий случай запихаю сюда
    beq a0, t0, process_input
    li t0, '\n'
    beq a0, t0, process_input
    
    # Проверка на переполнение буфера
    li t0, BUFFER_SIZE
    blt s2, t0, input_loop
    
process_input:
    sb zero, 0(s1)
    
    # Переходим в конец строки для проверки на наличие нежелательных символов
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
    li s3, 0
    
# =====================================================

# ====================== ВЫВОД ========================
output:
    la a0, sym_newline
    call puts
    
    # Проверки на команды -----------------------------
    # shutdown
    la a0, buffer
    la a1, shutdown_cmd
    call strcmp
    beqz a0, shutdown

    # reboot
    la a0, buffer 
    la a1, reboot_cmd
    call strcmp
    beqz a0, reboot

    # lsusb
    la a0, buffer 
    la a1, lsusb_cmd
    call strcmp
    beqz a0, lsusb

    #debug - для проперки отдельных элементов кода, в нашем случае kernel panic
    la a0, buffer
    la a1, debug_cmd
    call strcmp

    mv t0, a0
    la a0, msg_kernel_panic_0

    beqz t0, kernel_panic
    # -------------------------------------------------
    
    la a0, echo_cmd
    call puts
    la a0, buffer
    call puts
    la a0, sym_newline
    call puts
    
    j main_loop

# =====================================================



# ================= РЕАЛИЗАЦИЯ КОМАНД =================
# Команда shutdown
# 0x100000 - адрес для исполнения магических команд в зависимости от значения
shutdown:    
    li t0, 0x100000
    li t1, 0x5555 # shutdown
    sw t1, 0(t0)
    
    # если трюк не сработал - уходим в бесконечный цикл и наслаждаемся своей беспомощностью
    j shutdown

# Команда reboot
reboot:
    li t0, 0x100000 
    li t1, 0x7777 # reboot
    sw t1, 0(t0)
    
    # если не сработало, пытаемся просто выключить
    j shutdown 

# Команда lsusb
lsusb:
    
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
    la a0, sym_newline
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

# Сравнение строк
# a0 - строка из буфера
# a1 - строка, объявленная в коде
strcmp:
strcmp_loop:
    lb t0, 0(a0)
    lb t1, 0(a1)
    
    beqz t1, strcmp_equal
    bne t0, t1, strcmp_not_equal 
    
    # Увеличиваем индексы строк
    addi a0, a0, 1
    addi a1, a1, 1
    j strcmp_loop

strcmp_equal:
    li a0, 0
    ret

strcmp_not_equal:
    li a0, 1
    ret

# Вывод одного символа, кладём байт в UART
putc:
    li t0, UART0_BASE
    sb a0, 0(t0)
    ret

# Ввод одного символа, получить байт из UART
getc:
    li t0, UART0_BASE
1:
    lb t1, UART_LSR(t0)
    andi t1, t1, LSR_RX_READY
    beqz t1, 1b
    lb a0, 0(t0)
    ret

# Вывод строки
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
# =====================================================



# Вспомогательные строки
buffer:                 .space  32
echo_cmd:               .string "echo answered " # <- сделал не в совсем привычном виде, к командам не отношу

sym_newline:            .string "\r\n"
sym_space:              .string " "

# =================== Команды ===================
debug_cmd:              .string "debug"
shutdown_cmd:           .string "shutdown"
reboot_cmd:             .string "reboot"
lsusb_cmd:              .string "lsusb"
# ===============================================

# =============== Вспомогательное ===============
greetings:              .string "[BOOTED]: Kernel coded by Team 42.\r\n"
cmd_prefix:             .string "Simon says~: "

# ===============================================

# ================= Для ошибок ==================
msg_kernel_panic:       .string "[KERNEL PANIC]: "

# err messages
msg_kernel_panic_0:     .string "Debug"

# recommendation message
rec_kernel_panic_0:     .string "Please, press r to reboot\r\n"
rec_kernel_panic_1:     .string "...or press s to shutdown.\r\n"
# ===============================================
