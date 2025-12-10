#define UART_BASE 0x10000000

volatile char* uart = (volatile char*)UART_BASE;

void _main(void);
void codeend(void);

void _start(void) __attribute__((naked));
void _start(void) {
    asm volatile (
        "li sp, 0x87F00000\n"         // Инициализация стека
	"j _main\n"
    );
}

void print_string(const char* str) {
    while (*str) *uart = *str++;
}

void print_hex(unsigned long value) {
    const char* hex = "0123456789ABCDEF";
    for (int k = 60; k >= 0; k -= 4) {
        unsigned char nibble = (value >> k) & 0xF;
        *uart = hex[nibble];
    }
}

void _main(void) {
    print_string("Memory scanner\r\n");

    // Показываем границы кода
    print_string("Code start: 0x");
    unsigned long code_start = (unsigned long)_start;
    print_hex(code_start);
    print_string("\r\n");

    print_string("Code end:   0x");
    unsigned long code_end = (unsigned long)codeend;
    print_hex(code_end);
    print_string("\r\n\r\n");

    // === НАСТРОЙКИ СКАНИРОВАНИЯ ===
    unsigned long scan_start = 0x80001300;  // НАЧАЛО
    unsigned long scan_end   = 0x80FFFFFF;  // КОНЕЦ
    unsigned long step       = 0x1;         // ШАГ С КОТОРЫМ ИДЕМ ПО КОДУ
    print_string("Starting scan...\r\n\r\n");

    // === СКАНИРОВАНИЕ ===
    int in_region = 0;
    
    for (scan_start; scan_start <= scan_end; scan_start += step) {
        volatile char* test_addr = (volatile char*)scan_start;
        
        char original = *test_addr;
        *test_addr = 0xAA;
        
        // Проверяем что записалось
        if (*test_addr == 0xAA) {
            // Восстанавливаем оригинал
            *test_addr = original;
            
            if (!in_region) {
                in_region = 1;
                print_string("Region: 0x");
                print_hex(scan_start);
                print_string(" - 0x");
            }
        } else {
            if (in_region) {
                in_region = 0;
                print_hex(scan_start - step);
                print_string("\r\n");
            }
        }
    }

    // Завершаем последний регион
    if (in_region) {
        print_hex(scan_start - step);
        print_string("\r\n");
    }
    print_string("\r\nSCAN COMPLETE\r\n");
    while (1) {}
}

void codeend(void) {
    // Метка конца кода
}

