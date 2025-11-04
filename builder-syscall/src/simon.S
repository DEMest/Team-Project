#define UART0_BASE 0x10000000
#define UART_LSR   0x05
#define LSR_RX_READY 0x01
#define BUFFER_SIZE 0x10

# СПИСОК ПРОЦЕССОВ ==================
#define PS_LIST_ADDR 0x81000000

#define PS_MAX_PID 32
#define PS_STRUCT_SIZE 32

#define PS_STATE_OFFSET 0 
#define PS_NAME_OFFSET 1

#define PS_STATE_ZOMBIE 1
#define PS_STATE_RUNNING 2
#define PS_STATE_SLEEPING 3
# ===================================

.global _start
.section .text


# Справка по регистрам
#   a0-a1 - аргументные регистры (передача данных между функциями)
#   t0-t2 - временные регистры (для данных внутри функции)
#   s1-s3 - сохранённые (постоянные) регистры


# Стартовая точка, мы тут один раз
_start:
    la a0, kernel
    li a1, PS_STATE_RUNNING
    call add_process

    la a0, shtd_cmd
    li a1, PS_STATE_ZOMBIE
    call add_process

    la a0, greetings
    call puts



# Глобально сохраняем адрес на буфер и индекс буфера
main_loop:
    la a0, sym_newline
    call puts
    la a0, cmd_prefix
    call puts

    la s1, buffer
    li s2, 0
    
# ====================== ВВОД =========================
input_loop:
    call getc # Ждём символ
    call putc # Эхо-вывод
    # !!! по хорошему бы как-то отдельно обрабатывать кнопку backspace, иначе начинается стендап с вводом
    
    # Сохраняем символ в буфер
    sb a0, 0(s1)
    addi s1, s1, 1
    addi s2, s2, 1
    
    # Проверка на конец строки
    li t0, '\r' # Символ возврата каретки
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
    
# =====================================================

# ====================== ВЫВОД ========================
output:
    la a0, sym_newline
    call puts
    
    # Проверки на команды -----------------------------
    la a0, buffer
    la a1, shtd_cmd
    call strcmp
    beqz a0, shutdown

    la a0, buffer
    la a1, ps_cmd
    call strcmp
    beqz a0, process_list
    # -------------------------------------------------
    
    la a0, echo_cmd
    call puts
    la a0, buffer
    call puts
    
    j main_loop

# =====================================================



# ================= РЕАЛИЗАЦИЯ КОМАНД =================
# Команда shutdown
# Трюк с имитацией отключения питания
#   Если честно я сам не совсем понял магию чисел ниже
#   Логика такова, что питания нет -> железо не работает -> нечего эмулировать -> QEMU закрывается
shutdown:    
    li t0, 0x100000
    li t1, 0x5555
    sw t1, 0(t0)
    
    # если трюк не сработал - уходим в бесконечный цикл и наслаждаемся своей беспомощностью
    j shutdown

/* поломано   
process_list:
    # Заголовок
    la a0, ps_header
    call puts
    la a0, sym_newline
    call puts

    # Инициализация
    li t0, 0                # PID = 0
    li t1, PS_LIST_ADDR     # Базовый адрес списка
    li t6, PS_MAX_PID       # Максимум процессов

process_list_loop:
    bge t0, t6, process_list_done  # Если дошли до конца — выход

    # Вычисляем адрес структуры процесса
    li t2, PS_STRUCT_SIZE
    mul t3, t0, t2          # t3 = PID * размер структуры
    add t4, t1, t3          # t4 = адрес текущей структуры

    # Загружаем состояние
    lb t5, PS_STATE_OFFSET(t4)
    beqz t5, process_list_next   # Если 0 — слот пуст

    # Определяем строку состояния
    li t2, PS_STATE_RUNNING
    beq t5, t2, .print_running
    li t2, PS_STATE_SLEEPING
    beq t5, t2, .print_sleeping
    li t2, PS_STATE_ZOMBIE
    beq t5, t2, .print_zombie
    j process_list_next  

.print_running:
    la a0, state_running_str
    j .print_state

.print_sleeping:
    la a0, state_sleeping_str
    j .print_state

.print_zombie:
    la a0, state_zombie_str
    j .print_state

.print_state:
    call puts

    # Разделитель " | "
    la a0, ps_separator
    call puts

    # Имя процесса
    addi a0, t4, PS_NAME_OFFSET
    call puts

    # Перевод строки
    la a0, sym_newline
    call puts

process_list_next:
    addi t0, t0, 1
    j process_list_loop

process_list_done:
    j main_loop
*/
# =====================================================

# Сравнение строк
# 
# Передаваемые аргументы:
# a0 - адрес на первую строку
# a1 - адрес на вторую строку
# 
# Возвращает a0 = 0 если строки равны
strcmp:
strcmp_loop:
    lb t0, 0(a0)
    lb t1, 0(a1)
    
    bne t0, t1, strcmp_not_equal
    add t2, t0, t1 
    beqz t2, strcmp_equal
    
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

# Добавление процесса
#
# Передаваемые аргументы:
# a0 - адрес на название процесса
# a1 - состояние 
#
# Кладёт новый объявленный процесс в список
add_process:
    li t0, 0                    # PID
    li t1, PS_LIST_ADDR         # Адрес

add_process_search_loop:
    li t2, PS_STRUCT_SIZE
    mul t2, t2, t0              # PID * размер_структуры
    add t2, t2, t1              # Текущий адрес структуры

    lb t3, 0(t2)                # Загружаем состояние
    beqz t3, add_process_found_slot  # Если 0 - нашли слот

    addi t0, t0, 1
    j add_process_search_loop

add_process_found_slot:
    sb a1, 0(t2)                # Сохраняем состояние
    addi t2, t2, PS_NAME_OFFSET # Переходим к полю имени
    mv t3, a0                   # Источник - имя процесса
    li t4, 31                   # Максимум 31 байт для имени

add_process_copy_loop:
    beqz t4, add_process_done   # Если скопировали 31 байт - выходим
    lb t5, 0(t3)                # Загружаем байт из имени
    beqz t5, add_process_done   # Если нуль-терминатор - выходим
    sb t5, 0(t2)                # Сохраняем байт в структуру

    addi t2, t2, 1
    addi t3, t3, 1
    addi t4, t4, -1
    j add_process_copy_loop

add_process_done:
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



# Вспомогательные строки
debug: .string "debug\r\n"
sym_newline: .string "\r\n"
sym_space: .string " "
greetings: .string "Coded by Team 42."
cmd_prefix: .string "Simon says~: "
kernel: .string "simon"

# Команды ===================
shtd_cmd: .string "shutdown"
ps_cmd: .string "ps"
# ===========================

# Вспомогательное ===========
ps_header: .string "State | Name"
ps_separator: .string " | "
state_running_str: .string "Running"
state_sleeping_str: .string "Sleeping" 
state_zombie_str: .string "Zombie"
state_unknown: .string "Unknown"
# ===========================

echo_cmd: .string "echo answered " # <- сделал не в совсем привычном виде, к командам не отношу
buffer: .space 32
