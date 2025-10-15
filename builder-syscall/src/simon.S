#define UART0_BASE 0x10000000
#define UART_LSR   0x05
#define LSR_RX_READY 0x01
#define BUFFER_SIZE 0x10

.global _start
.section .text


# Справка по регистрам
#   a0-a1 - аргументные регистры (передача данных между функциями)
#   t0-t2 - временные регистры (для данных внутри функции)
#   s1-s3 - сохранённые (постоянные) регистры


# Вывод приветственного сообщения и префикс строки
_start:
    la a0, greetings
    call puts
    la a0, cmd_prefix
    call puts

# Глобально сохраняем адрес на буфер и индекс буфера
main_loop:
    la s1, buffer
    li s2, 0
    
# Логика ввода
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
    

# !!! Строки должны заканчиваться нулями, от этого зависит работа того же strcmp
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
    

# Логика ответа (вывода)
output:
    la a0, newline
    call puts
    
    # Проверка на команду shutdown
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



# Трюк с имитацией отключения питания
# Если честно я сам не совсем понял магию чисел ниже
# Логика такова, что питания нет -> железо не работает -> нечего эмулировать -> QEMU закрывается
shutdown:    
    li t0, 0x100000
    li t1, 0x5555
    sw t1, 0(t0)
    
    # если трюк не сработал - уходим в бесконечный цикл и наслаждаемся своей беспомощностью
    j shutdown



# Сравнение строк
# a0 - адрес на первую строку
# a1 - адрес на вторую строку
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
greetings:
    .string "Coded by Team 42.\r\n"

cmd_prefix:
    .string "Simon says~: "

newline:
    .string "\r\n"

# Команды ===================
shtd_cmd:
    .string "shutdown"
# ===========================

echo_cmd: # <- сделал не в совсем привычном виде, к командам не отношу
    .string "echo answered "

buffer:
    .space 16
