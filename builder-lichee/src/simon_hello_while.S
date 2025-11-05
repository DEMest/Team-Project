#define UART0_BASE 0x10000000
#define BUFFER_SIZE 0x10

# Константы для функции print
# Максимальное количество символов для отправки за один блок
.equ MAX_CHARS, 16

# Константа для задержки 1.4 мс
# Значение зависит от тактовой частоты процессора.
# Принимаем, что 100000 итераций цикла delay_loop дают приблизительно 1.4 мс задержки.
.equ DELAY_COUNT, 1000000

.global _start
.section .text


# Справка по регистрам
#   a0 - аргумент 1 (адрес строки) / возвращаемое значение (адрес следующего символа)
#   t0-t2 - временные регистры
#   s0-s2 - сохранённые регистры

_start:
    # Инициализация сохраненных регистров
    la s1, greetings  # Адрес приветственного сообщения

# Бесконечный цикл отправки приветствий
main_loop:
    # Отправка приветствия
    la a0, greetings
    call puts
    
    # Отправка перевода строки
    la a0, newline
    call puts
    
    call delay_1_4ms
    
    j main_loop
    
# Функция задержки на 1.4 мс
# Использует t0 как временный регистр
delay_1_4ms:
    li t0, DELAY_COUNT
delay_loop:
    addi t0, t0, -1
    bnez t0, delay_loop
    ret

puts:
    mv t1, a0
    li t2, UART0_BASE
puts_loop:
    lb a0, (t1)
    beqz a0, puts_done
    sb a0, 0(t2)
    addi t1, t1, 1
    call delay_1_4ms
    j puts_loop
puts_done:
    ret



# Вспомогательные строки
greetings:
    .string "Hello from RISCV UART! Team 42 greetings! This is a very long string to test the block printing functionality."

newline:
    .string "\r\n"

