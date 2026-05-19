include config.mk

CFLAGS ?= -mabi=lp64d -march=rv64gc -nostdlib -nostartfiles -ffreestanding
OBJCOPY_FLAGS ?= -O binary

INTERMEDIATE_FILES = boot.elf boot.bin payload.elf payload.bin payload.hex0 src/payload.hex0
WRAPPED_BIN = simon_wrapped.img

all: $(FINAL_FLASH_IMG)
	@$(MAKE) --no-print-directory clean_tmp

clean_tmp:
	@echo "Очищаем временные файлы..."
	@rm -f $(INTERMEDIATE_FILES) $(YOUR_RAW_BIN) $(WRAPPED_BIN)
	@echo "Остался только $(FINAL_FLASH_IMG)"

payload.hex0: $(PAYLOAD_SRC)
	$(CC) $(DEFINES) $(CFLAGS) -Ttext=$(PAYLOAD_LOAD_ADDR) $(PAYLOAD_SRC) -o payload.elf
	$(OBJCOPY) $(OBJCOPY_FLAGS) payload.elf payload.bin
	chmod +x ./bin-to-hex0.sh
	./bin-to-hex0.sh payload.bin src/payload.hex0
	printf '\0' >> src/payload.hex0

$(YOUR_RAW_BIN): $(BOOT_SRC) payload.hex0
	$(CC) $(DEFINES) $(CFLAGS) -Ttext=$(SRAM_BASE_FOR_LINK) $(BOOT_SRC) -o boot.elf
	$(OBJCOPY) $(OBJCOPY_FLAGS) boot.elf boot.bin
	cat boot.bin src/payload.hex0 > $@

$(WRAPPED_BIN): $(YOUR_RAW_BIN)
	$(MKIMAGE) -A riscv -O u-boot -T standalone -C none \
	-a $(DDR_ADDR) -e $(DDR_ADDR) -n "SimonOS" \
	-d $(YOUR_RAW_BIN) $@

$(FINAL_FLASH_IMG): $(WRAPPED_BIN)
	@echo "Собираем образ для флешки..."
	dd if=/dev/zero of=$@ bs=1M count=4
	dd if=$(SPL_BIN) of=$@ conv=notrunc
	dd if=$(WRAPPED_BIN) of=$@ bs=1k seek=1024 conv=notrunc
	@echo "ГОТОВО! Проверь устройство через lsblk перед dd"

clean:
	rm -f $(INTERMEDIATE_FILES) $(WRAPPED_BIN) $(YOUR_RAW_BIN) $(FINAL_FLASH_IMG)

.PHONY: all clean clean_tmp
