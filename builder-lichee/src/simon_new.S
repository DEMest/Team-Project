#define UART0_BASE 0xFFE7014000

#define UART_LSR   0x05
#define LSR_RX_READY 0x01
#define BUFFER_SIZE 0x10


#задержка вывода символа в юарт
.equ DELAY_COUNT, 1000


.global _start
.section .text

# Справка по регистрам
#   a0-a1 - аргументные регистры (передача данных между функциями)
#   t0-t2 - временные регистры (для данных внутри функции)
#   s1-s3 - сохранённые (постоянные) регистры

# Вывод приветственного сообщения и префикс строки
_start:
    la a0, newline
    call print


main_loop:
    # Отправка приветствия
    la a0, greetings
    call print
    
    # Отправка перевода строки
    la a0, newline
    call print
    
    call delay_1_4ms
    
    j main_loop
    
    
    
    
    
    
    
#выводит символы из a0
#трогает регистры t1, t2
print:
    mv t1, a0
    li t2, UART0_BASE
puts_loop:
    lb a0, (t1)
    beqz a0, puts_done
    sb a0, 0(t2)
    addi t1, t1, 1
    
    li t0, DELAY_COUNT
delay_in_loop:
    addi t0, t0, -1
    bnez t0, delay_in_loop
    
    j puts_loop
puts_done:
    ret
    
    
delay_1_4ms:
    li t0, DELAY_COUNT
delay_loop:
    addi t0, t0, -1
    bnez t0, delay_loop
    ret


greetings:
    .string "Hello from RISCV UART! Team 42 greetings! This is a very long string to test the block printing functionality."

newline:
    .string "\r\n"

