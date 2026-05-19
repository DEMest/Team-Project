#ifdef QEMU
#define UART0_BASE 0x10000000
#else
#define UART0_BASE 0xFFE7014000
#endif

#define UART_LSR     0x14
#define LSR_RX_READY 0x01
#define LSR_TX_IDLE  0x20
#define BUFFER_SIZE  0x10

.global _start
.section .text

# Справка по регистрам
#   a0-a1 - аргументные регистры (передача данных между функциями)
#   t0-t2 - временные регистры (для данных внутри функции)
#   s1-s3 - сохранённые (постоянные) регистры

_start:
    # --- ВЫВОД PROGRAM COUNTER (PC) ---
    auipc s1, 0 
    
    la a0, pc_msg
    call puts
    
    mv a0, s1
    call print_hex
    
    la a0, newline
    call puts
    # ----------------------------------

    # Вывод приветственного сообщения
    la a0, greetings
    call puts
    
    # === БЕЗОПАСНЫЙ ТЕСТ ПАМЯТИ DDR ===
    li s3, 0x40080000       # Безопасный адрес для записи (внутри разрешенных 1.5 МБ)
    la s4, ddr_test_str     # Адрес исходной строки
    
copy_loop:
    lb t0, 0(s4)            # Читаем 1 байт из ROM/Флешки
    sb t0, 0(s3)            # Пишем этот байт в живую DDR по адресу 0x40080000
    beqz t0, copy_done      # Если нуль-терминатор - выходим
    addi s3, s3, 1          
    addi s4, s4, 1          
    j copy_loop             
    
copy_done:
    # Теперь читаем и выводим строку прямо из DDR!
    li a0, 0x40080000       
    call puts               
    # ==================================

    la a0, cmd_prefix
    call puts

# Глобально сохраняем адрес на буфер и индекс буфера
main_loop:
    la s1, buffer
    li s2, 0
    
# Логика ввода
input_loop:
    call getc # Ждём символ из UART
    call putc # Эхо-вывод обратно в терминал
    
    # Сохраняем символ в буфер
    sb a0, 0(s1)
    addi s1, s1, 1
    addi s2, s2, 1
    
    # Проверка на конец строки (Enter)
    li t0, '\r' 
    beq a0, t0, process_input
    li t0, '\n'
    beq a0, t0, process_input
    
    # Проверка на переполнение буфера
    li t0, BUFFER_SIZE
    blt s2, t0, input_loop
    

process_input:
    sb zero, 0(s1)
    
    # Переходим в конец строки для удаления нежелательных символов \r \n
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
    
    # Вывод эха
    la a0, echo_cmd
    call puts
    la a0, buffer
    call puts
    la a0, newline
    call puts
    la a0, cmd_prefix
    call puts
    
    j main_loop


shutdown:    
    li t0, 0x100000
    li t1, 0x5555
    sw t1, 0(t0)
    j shutdown


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


# --- Функция для вывода 64-битного адреса в HEX ---
print_hex:
    mv t3, a0          
    li t4, 60          
    li t5, UART0_BASE  
print_hex_loop:
    srl t0, t3, t4     
    andi t0, t0, 0xF   
    
    li t1, 9
    bgt t0, t1, hex_letter
hex_digit:
    addi t0, t0, '0'   
    j print_hex_char
hex_letter:
    addi t0, t0, 55    
    
print_hex_char:
wait_tx_hex:
    lb t6, UART_LSR(t5)
    andi t6, t6, LSR_TX_IDLE 
    beqz t6, wait_tx_hex
    
    sb t0, 0(t5)       
    
    addi t4, t4, -4    
    bgez t4, print_hex_loop
    ret


# --- Ввод одного символа (Чтение) ---
getc:
    li t0, UART0_BASE
1:
    lb t1, UART_LSR(t0)
    andi t1, t1, LSR_RX_READY 
    beqz t1, 1b
    lb a0, 0(t0)
    ret


# --- Вывод одного символа (Эхо) ---
putc:
    li t0, UART0_BASE
wait_tx_putc:
    lb t1, UART_LSR(t0)
    andi t1, t1, LSR_TX_IDLE 
    beqz t1, wait_tx_putc
    
    sb a0, 0(t0)
    ret


# --- Вывод строки ---
puts:
    mv t2, a0           
    li t3, UART0_BASE
puts_loop:
    lb t4, 0(t2)        
    beqz t4, puts_done  
wait_tx_puts:
    lb t5, UART_LSR(t3) 
    andi t5, t5, LSR_TX_IDLE 
    beqz t5, wait_tx_puts    
    
    sb t4, 0(t3)        
    addi t2, t2, 1      
    j puts_loop
puts_done:
    ret



# ========================================
# ДАННЫЕ И СТРОКИ
# ========================================
pc_msg:
    .string "Current PC: 0x"

greetings:
    .string "Coded by Team 42.\r\n"

ddr_test_str:
    .string "DDR R/W TEST: SUCCESS! Hello from 0x40080000\r\n"

cmd_prefix:
    .string "Simon says~: "

newline:
    .string "\r\n"

shtd_cmd:
    .string "shutdown"

echo_cmd:
    .string "echo answered "

# --- СЕКЦИЯ ПАМЯТИ ---
# Выделяем память под буфер ввода
.section .bss
.align 12
buffer:
    .space 16
