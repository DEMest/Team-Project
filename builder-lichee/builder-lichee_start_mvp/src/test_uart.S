#define UART0_BASE_HI 0xffe70
#define UART0_BASE_LO 0x14000

#define UART_RBR   0x00    # Receive Buffer Register (read)
#define UART_THR   0x00    # Transmit Holding Register (write)
#define UART_LSR   0x14    # Line Status Register

#define LSR_DR     0x01    # Data Ready (bit 0)
#define LSR_THRE   0x20    # Transmitter Holding Register Empty (bit 5)

.equ DELAY_COUNT, 100

.global _start
.section .text

_start:
    # Загружаем адрес UART0
    lui t3, UART0_BASE_HI
    addi t3, t3, UART0_BASE_LO
    # t3 = адрес UART0 = 0xFFE7014000
    
    # Отправляем приветствие
    la a0, greetings
    call puts
    
    la a0, newline
    call puts

main_loop:
    # Ждём ввода символа
    call getc
    # a0 = полученный символ
    
    # Отправляем его обратно (эхо)
    call putc
    
    # Отправляем новую строку
    la a0, newline
    call puts
    
    j main_loop


#
# putc: Отправить один символ
# Input: a0 = символ, t3 = адрес UART0
# Clobbers: t0
#
putc:
    # Сохраняем символ
    mv t0, a0
    
    # Ждём, пока UART будет готов к передаче
wait_tx_ready:
    lw a0, UART_LSR(t3)    # Читаем Line Status Register
    andi a0, a0, LSR_THRE  # Проверяем бит THRE (Transmitter Holding Register Empty)
    beqz a0, wait_tx_ready # Если не готов, ждём
    
    # Отправляем символ
    sb t0, UART_THR(t3)
    ret


#
# getc: Получить один символ
# Input: t3 = адрес UART0
# Output: a0 = полученный символ
# Clobbers: t0
#
getc:
    # Ждём, пока данные будут готовы
wait_rx_ready:
    lw t0, UART_LSR(t3)    # Читаем Line Status Register
    andi t0, t0, LSR_DR    # Проверяем бит DR (Data Ready)
    beqz t0, wait_rx_ready # Если нет данных, ждём
    
    # Читаем символ
    lbu a0, UART_RBR(t3)
    ret


#
# puts: Отправить строку (null-terminated)
# Input: a0 = адрес строки, t3 = адрес UART0
# Clobbers: t0, t1, a0
#
puts:
    mv t1, a0              # t1 = адрес строки
    
puts_loop:
    lbu a0, 0(t1)          # Читаем символ
    beqz a0, puts_done     # Если конец строки (0), выходим
    
    call putc              # Отправляем символ
    
    addi t1, t1, 1         # Переходим к следующему символу
    j puts_loop
    
puts_done:
    ret


#
# Data section
#
.section .data

greetings:
    .string "Hello from RISCV UART! Team 42 greetings!"

newline:
    .string "\r\n"
