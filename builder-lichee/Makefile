include config.mk

# Временные файлы, которые будем удалять
INTERMEDIATE_FILES = boot.elf boot.bin payload.elf payload.bin payload.hex0
WRAPPED_BIN = simon_wrapped.img
# Если у тебя есть boot.cmd и boot.scr, и ты хочешь их удалять — добавь сюда:
# INTERMEDIATE_FILES += boot.cmd boot.scr

all: $(FINAL_FLASH_IMG)
	@$(MAKE) --no-print-directory clean_tmp

# Очистка временных файлов (не трогает финальный образ)
clean_tmp:
	@echo "Очищаем временные файлы..."
	@rm -f $(INTERMEDIATE_FILES) $(YOUR_RAW_BIN) $(WRAPPED_BIN)
	@echo "Остался только $(FINAL_FLASH_IMG)"

# 1. Собираем "сырой" бинарник
$(YOUR_RAW_BIN): $(BOOT_SRC) $(PAYLOAD_SRC)
	$(CC) -march=rv64gc -nostdlib -Ttext=$(DDR_ADDR) $(BOOT_SRC) -o boot.elf
	$(OBJCOPY) -O binary boot.elf boot.bin
	$(CC) -march=rv64gc -nostdlib -Ttext=$(DDR_ADDR) $(PAYLOAD_SRC) -o payload.elf
	$(OBJCOPY) -O binary payload.elf payload.bin
	./bin-to-hex0.sh payload.bin payload.hex0
	cat boot.bin payload.hex0 > $@

# 2. Оборачиваем в заголовок U-Boot
$(WRAPPED_BIN): $(YOUR_RAW_BIN)
	$(MKIMAGE) -A riscv -O u-boot -T standalone -C none \
	-a $(DDR_ADDR) -e $(DDR_ADDR) -n "SimonOS" \
	-d $(YOUR_RAW_BIN) $@

# 3. Склеиваем всё для dd (без удаления внутри — удаление будет после all)
$(FINAL_FLASH_IMG): $(WRAPPED_BIN)
	@echo "Собираем образ для флешки..."
	dd if=/dev/zero of=$@ bs=1M count=4
	dd if=$(SPL_BIN) of=$@ conv=notrunc
	dd if=$(WRAPPED_BIN) of=$@ bs=1k seek=1024 conv=notrunc
	@echo "ГОТОВО! Шей: sudo dd if=$@ of=/dev/sdc status=progress"

# Полная очистка (включая финальный образ)
clean:
	rm -f $(INTERMEDIATE_FILES) $(WRAPPED_BIN) $(YOUR_RAW_BIN) $(FINAL_FLASH_IMG)

.PHONY: all clean clean_tmp
