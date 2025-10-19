#define UART0_BASE 0x10000000
#define BUFFER_SIZE 0x10

.global _start
.section .text

# Справка по регистрам
#   a0-a1 - аргументные регистры
#   t0-t2 - временные регистры
#   s1-s2 - сохранённые регистры

_start:
    # Инициализация сохраненных регистров
    la s1, greetings  # Адрес приветственного сообщения
    li s2, 0          # Счетчик для задержки

# Бесконечный цикл отправки приветствий
main_loop:
    # Отправка приветствия
    mv a0, s1
    call puts
    
    # Отправка перевода строки
    la a0, newline
    call puts
    
    # Простая задержка (можно регулировать значение)
    li t0, 1000000
delay_loop:
    addi t0, t0, -1
    bnez t0, delay_loop
    
    j main_loop

# Вывод одного символа в UART
putc:
    li t0, UART0_BASE
    sb a0, 0(t0)
    ret

# Вывод строки (завершающейся нулем)
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
    .string "Hello from RISC-V UART! Team 42 greetings!"

newline:
    .string "\r\n"

# Буфер (оставлен для совместимости, но не используется)
buffer:
    .space 16
