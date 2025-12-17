# Компилятор и флаги
CC = riscv64-unknown-elf-gcc
CFLAGS = -march=rv64gc -mabi=lp64 -mcmodel=medany -nostdlib -ffreestanding -O0
LDFLAGS = -Wl,-Ttext=0x80000000

# Исходные файлы
SOURCES = memorytest.c
TARGET = main
QEMU_MEMORY = 128M

# Цели по умолчанию
all: $(TARGET).bin

# Компиляция в ELF
$(TARGET).elf: $(SOURCES)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

# Конвертация в бинарный формат
$(TARGET).bin: $(TARGET).elf
	riscv64-unknown-elf-objcopy -O binary $< $@

# Запуск в QEMU
run: $(TARGET).bin
	qemu-system-riscv64 -M virt -m $(QEMU_MEMORY) -nographic -bios none -kernel $(TARGET).bin

# Запуск с выводом в stdio
run-stdio: $(TARGET).bin
	qemu-system-riscv64 -M virt -m $(QEMU_MEMORY) -nographic -bios none -kernel $(TARGET).bin -serial stdio

# Отладка
debug: $(TARGET).bin
	qemu-system-riscv64 -M virt -m $(QEMU_MEMORY) -nographic -bios none -kernel $(TARGET).bin -s -S

# Очистка
clean:
	rm -f *.elf *.bin

# Показать помощь
help:
	@echo "Доступные команды:"
	@echo "  make all     - Скомпилировать бинарник"
	@echo "  make run     - Запустить в QEMU"
	@echo "  make debug   - Запустить в режиме отладки"
	@echo "  make clean   - Очистить скомпилированные файлы"
	@echo "  make help    - Показать эту справку"

.PHONY: all run run-stdio debug clean help
