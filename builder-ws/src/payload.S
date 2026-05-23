#ifdef QEMU
#define UART0_BASE 0x10000000
#else
#define UART0_BASE 0xFFE7014000
#endif

.global _start
.section .text

_start:
        la s1, hello

        loop:
                lb a0, (s1)
                beqz a0, halt
                addi s1, s1, 1
                call uart_putc
                j loop       

halt:
        j halt

# a0 -- char to display
uart_putc:
        li a1, UART0_BASE
        sb a0, (a1)
        ret

hello:
.string "Hello, World!"

payload:
