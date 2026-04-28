.global _start
_start:
    li a0, 0x41
    call uart_putc
    j halt

uart_putc:
    lui a1, 0x10000
    sb a0, 0(a1)
    ret

halt:
    j halt