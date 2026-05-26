#ifdef QEMU
#define UART0_BASE              0x10000000
#define UART_LSR                5
#define MEM_BASE                0x80000000
#define MAGIC_ADDRESS           0x100000
#define FREE_RAM_START          0x81000000
#define FREE_RAM_END            0x87ffffff
#else // LICHEE_PI_4A
#define UART0_BASE              0xFFE7014000
#define UART_LSR                0x14
#define MEM_BASE                0x40000000
#define MAGIC_ADDRESS           0x100000 // Placeholder, real HW shutdown is complex
#define FREE_RAM_START          0x40040000
#define FREE_RAM_END            0x40ffffff
#endif

#define LSR_RX_READY            1
#define LSR_TX_IDLE             0x20
#define BUFFER_SIZE             32

#define SHUTDOWN_SIG            0x5555
#define REBOOT_SIG              0x7777

#define PAGE_SIZE               8192 
#define PROC_MAX                8
#define PROC_PAGES              3

#define PROC_STATE_UNUSED       0x0000
#define PROC_STATE_RUNNING      0xffffffffffffffff

#define PROC_SHIFT_PID          0
#define PROC_SHIFT_STATE        8
#define PROC_SHIFT_SP_ADDR      16

#define PROC_STACK_SIZE         0x4000          

.global _start
.global yield
.global create_process
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
    # TH1520 watchdog base
    li t0, 0xFFEFC30000

    # timeout = 1
    li t1, 1
    sw t1, 0x4(t0)

    # enable watchdog + reset
    li t1, 0x3
    sw t1, 0x0(t0)

1:
    j 1b

debug:
    # A descriptor = FREE_RAM_START
    # B descriptor = FREE_RAM_START + 0x6000

    # подготовить начальный контекст процесса B
    li t0, (FREE_RAM_START + 0x6000)      # descriptor B
    li t1, (FREE_RAM_START + 0x6000 + PROC_STACK_SIZE - 160)

    la t2, test_b
    sd t2, 0(t1)                          # ra = test_b

    # остальные сохранённые регистры = 0
    sd zero, 8(t1)
    sd zero, 16(t1)
    sd zero, 24(t1)
    sd zero, 32(t1)
    sd zero, 40(t1)
    sd zero, 48(t1)
    sd zero, 56(t1)
    sd zero, 64(t1)
    sd zero, 72(t1)
    sd zero, 80(t1)
    sd zero, 88(t1)
    sd zero, 96(t1)
    sd zero, 104(t1)
    sd zero, 112(t1)
    sd zero, 120(t1)
    sd zero, 128(t1)
    sd zero, 136(t1)
    sd zero, 144(t1)
    sd zero, 152(t1)

    sd t1, PROC_SHIFT_SP_ADDR(t0)         # сохранить sp процесса B

    j test_a


test_a:
    la a0, debug_a
    call puts
    li s0, 100

test_a_loop:
    beqz s0, debug_done
    addi s0, s0, -1

    li a0, 'A'
    call putc

    li a0, FREE_RAM_START
    li a1, (FREE_RAM_START + 0x6000)
    call switch_context

    j test_a_loop

debug_done:
    la a0, prompt
    call puts
    j main_loop


test_b:
    la a0, debug_b
    call puts

test_b_loop:
    li a0, 'B'
    call putc

    li a0, (FREE_RAM_START + 0x6000)
    li a1, FREE_RAM_START
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
	
    /* тут тип можно показывать аддрес аллокейта, но 
    la a0, allocated_page_addr
    call puts
    mv a0, t4
    call puth			<=== не ломает личи, поэтому обходимся без этого
    */
    
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
    addi sp, sp, -160

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
    sd t0, 104(sp)
    sd t1, 112(sp)
    sd t2, 120(sp)
    sd t3, 128(sp)
    sd t4, 136(sp)
    sd t5, 144(sp)
    sd t6, 152(sp)

    # сохранить текущий sp в descriptor текущего процесса
    sd sp, PROC_SHIFT_SP_ADDR(a0)

    # загрузить sp следующего процесса из его descriptor
    ld sp, PROC_SHIFT_SP_ADDR(a1)

    ld t6, 152(sp)
    ld t5, 144(sp)
    ld t4, 136(sp)
    ld t3, 128(sp)
    ld t2, 120(sp)
    ld t1, 112(sp)
    ld t0, 104(sp)
    ld s11, 96(sp)
    ld s10, 88(sp)
    ld s9, 80(sp)
    ld s8, 72(sp)
    ld s7, 64(sp)
    ld s6, 56(sp)
    ld s5, 48(sp)
    ld s4, 40(sp)
    ld s3, 32(sp)
    ld s2, 24(sp)
    ld s1, 16(sp)
    ld s0, 8(sp)
    ld ra, 0(sp)

    addi sp, sp, 160
    ret
    

create_process:
    # a0 - entry point
    # a1 - process name (optional)
    addi sp, sp, -16
    sd ra, 0(sp)
    
    # Simple logic: just store the entry point in the process descriptor
    li t0, FREE_RAM_START
    sd a0, PROC_SHIFT_SP_ADDR(t0) # Simplified: using first slot
    
    ld ra, 0(sp)
    addi sp, sp, 16
    ret

# --- UART Functions ---
getc:
    li t0, UART0_BASE
getc_wait:
    lb t1, UART_LSR(t0)
    andi t1, t1, LSR_RX_READY
    beqz t1, getc_wait
    lb a0, 0(t0)
    ret

putc:
    li t0, UART0_BASE
putc_wait:
    lb t1, UART_LSR(t0)
    andi t1, t1, LSR_TX_IDLE
    beqz t1, putc_wait
    sb a0, 0(t0)
    ret

puts:
    mv t2, a0
    li t3, UART0_BASE
puts_loop:
    lb t4, 0(t2)
    beqz t4, puts_done
wait_tx:
    lb t5, UART_LSR(t3)
    andi t5, t5, LSR_TX_IDLE
    beqz t5, wait_tx
    sb t4, 0(t3)
    addi t2, t2, 1
    j puts_loop
puts_done:
    ret

# --- Placeholder for puth (Hex print) ---
puth:
    la a0, sym_newline
    call puts
    ret

.section .data
.align 8
free_ram_pointer: .quad 0
buffer: .space BUFFER_SIZE
greetings: .string "SimonOS v2.0 (Adapted for Lichee Pi 4A)\r\n"
cmd_prefix: .string "Simon says~: "
echo_cmd: .string "Echo: "
shutdown_cmd: .string "shutdown"
reboot_cmd: .string "reboot"
debug_cmd: .string "debug"
ls_cmd: .string "ls"
hex0_cmd: .string "hex0"
do_cmd: .string "do"
sym_newline: .string "\r\n"
msg_kernel_panic: .string "Kernel Panic: "
msg_kernel_panic_2: .string "Kernel Panic: No free pages!\r\n"
msg_kernel_panic_4: .string "Kernel Panic: Idle process died\r\n"
rec_kernel_panic_0: .string "(r)eboot or (s)hutdown?\r\n"
rec_kernel_panic_1: .string "(r)eboot or (s)hutdown?\r\n"
allocated_page_addr: .string "Allocated page at: \r\n"
debug_a: .string "Debug A\r\n"
debug_b: .string "Debug B\r\n"
prompt: .string "\r\nEnd Debug\r\n"


.section .data
.align 12
ddr_touch_padding:
    .space 0x1000000
