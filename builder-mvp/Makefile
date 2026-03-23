# Компилятор и утилиты
CROSS_COMPILE = riscv-none-elf-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy

# Флаги компиляции
CFLAGS = -mabi=lp64d -march=rv64gc -nostdlib -ffreestanding

# Настраиваемые имена файлов (можно переопределить при вызове make)
BOOT_SRC ?= src/boot.S
PAYLOAD_SRC ?= src/simon.S
OUTPUT_IMAGE ?= image_qemu.bin

# Автоматически генерируем имена промежуточных файлов на основе входных
BOOT_NAME = $(basename $(notdir $(BOOT_SRC)))
PAYLOAD_NAME = $(basename $(notdir $(PAYLOAD_SRC)))

BOOT_ELF = $(BOOT_NAME).elf
BOOT_BIN = $(BOOT_NAME).bin
PAYLOAD_ELF = $(PAYLOAD_NAME).elf
PAYLOAD_BIN = $(PAYLOAD_NAME).bin
PAYLOAD_HEX0 = $(PAYLOAD_NAME).hex0

# Все временные файлы для очистки
TEMP_FILES = $(BOOT_ELF) $(BOOT_BIN) $(PAYLOAD_ELF) $(PAYLOAD_BIN) $(PAYLOAD_HEX0)

# Цель по умолчанию - ВСЕГДА пересобираем
.PHONY: all
all: clean-temp
	@echo "Начало сборки..."
	$(CC) $(CFLAGS) -Ttext=0x80000000 $(BOOT_SRC) -o $(BOOT_ELF)
	$(OBJCOPY) -O binary $(BOOT_ELF) $(BOOT_BIN)
	$(CC) $(CFLAGS) -Ttext=0x80000000 $(PAYLOAD_SRC) -o $(PAYLOAD_ELF)
	$(OBJCOPY) -O binary $(PAYLOAD_ELF) $(PAYLOAD_BIN)
	chmod +x ./bin-to-hex0.sh
	./bin-to-hex0.sh $(PAYLOAD_BIN) $(PAYLOAD_HEX0)
	cat $(BOOT_BIN) $(PAYLOAD_HEX0) > $(OUTPUT_IMAGE)
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
		qemu-system-riscv64 -M virt -bios $(OUTPUT_IMAGE) -monitor stdio; \
	else \
		echo "Файл $(OUTPUT_IMAGE) не существует. Выполните 'make' для сборки."; \
	fi

# Сборка и запуск одной командой
.PHONY: build-and-run
build-and-run: all run

# Пересборка (аналогично all)
.PHONY: rebuild
rebuild: all
