# Компилятор и утилиты
# В WSL/Linux: riscv64-unknown-elf-  |  В Windows: riscv-none-elf-
CROSS_COMPILE ?= riscv64-unknown-elf-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy

# Флаги компиляции
CFLAGS = -mabi=lp64d -march=rv64gc -nostdlib -ffreestanding

# Настраиваемые имена файлов (можно переопределить при вызове make)
BOOT_SRC ?= src/boot.S
SIMON_SRC ?= src/simon.S
FS_FILES ?= payload.hex0
OUTPUT_IMAGE ?= image_qemu.bin

BOOT_ELF = boot.elf
BOOT_BIN = boot.bin
SIMON_ELF = simon.elf
SIMON_BIN = simon.bin
SIMON_HEX0 = simon.hex0

# Все временные файлы для очистки
TEMP_FILES = $(BOOT_ELF) $(BOOT_BIN) $(SIMON_ELF) $(SIMON_BIN) $(SIMON_HEX0)

# Цель по умолчанию - ВСЕГДА пересобираем
.PHONY: all
all: clean-temp
	@echo "Начало сборки..."
	$(CC) $(CFLAGS) -Ttext=0x80000000 $(BOOT_SRC) -o $(BOOT_ELF)
	$(OBJCOPY) -O binary $(BOOT_ELF) $(BOOT_BIN)
	$(CC) $(CFLAGS) -Ttext=0x80000000 $(SIMON_SRC) -o $(SIMON_ELF)
	$(OBJCOPY) -O binary $(SIMON_ELF) $(SIMON_BIN)
	chmod +x ./bin-to-hex0.sh
	./bin-to-hex0.sh $(SIMON_BIN) $(SIMON_HEX0)
	./add_null.sh $(SIMON_HEX0)
	cat $(BOOT_BIN) $(SIMON_HEX0) $(FS_FILES) > $(OUTPUT_IMAGE)
	@echo "Создан образ: $(OUTPUT_IMAGE) (размер: $(shell stat -c%s $(OUTPUT_IMAGE)) байт)"
	@echo "Удаление временных файлов..."
	rm -f $(TEMP_FILES)

# Очистка временных файлов
.PHONY: clean-temp
clean-temp:
	rm -f $(TEMP_FILES)

# Полная очистка (включая итоговый образ)
.PHONY: clean
clean: clean-temp
	rm -f $(OUTPUT_IMAGE)
	@echo "Все файлы сборки удалены"

# Информация о текущих настройках
.PHONY: info
info:
	@echo "Текущие настройки:"
	@echo "  Загрузчик: $(BOOT_SRC)"
	@echo "  Полезная нагрузка: $(PAYLOAD_SRC)"
	@echo "  Выходной образ: $(OUTPUT_IMAGE)"
	@echo "  Временные файлы: $(TEMP_FILES)"

# Просмотр размеров файлов
.PHONY: size
size:
	@if [ -f "$(OUTPUT_IMAGE)" ]; then \
		echo "=== РАЗМЕР ФАЙЛА ==="; \
		stat -c "%-20n: %s байт" $(OUTPUT_IMAGE) 2>/dev/null || \
		ls -la $(OUTPUT_IMAGE) | awk 'NR>1 {printf "%-20s: %s байт\n", $$9, $$5}'; \
	else \
		echo "Файл $(OUTPUT_IMAGE) не существует. Выполните 'make' для сборки."; \
	fi

# Тестирование в QEMU
.PHONY: run
run:
	@if [ -f "$(OUTPUT_IMAGE)" ]; then \
		echo "Запуск в QEMU..."; \
		qemu-system-riscv64 -M virt -bios $(OUTPUT_IMAGE) -nographic; \
	else \
		echo "Файл $(OUTPUT_IMAGE) не существует. Выполните 'make' для сборки."; \
	fi

# Сборка и запуск одной командой
.PHONY: build-and-run
build-and-run: all run

# Пересборка (аналогично all)
.PHONY: rebuild
rebuild: all
