include config.mk

CFLAGS = -march=rv64gc -nostdlib -ffreestanding
OBJCOPY_FLAGS = -O binary

WRAPPED_BIN = simon_wrapped.img

.PHONY: all force clean rebuild

all: force $(FINAL_FLASH_IMG)

force:
	@true

$(YOUR_RAW_BIN): force
	@echo "Собираем boot..."
	$(CC) $(CFLAGS) -Ttext=$(DDR_ADDR) $(BOOT_SRC) -o boot.elf
	$(OBJCOPY) $(OBJCOPY_FLAGS) boot.elf boot.bin

	@echo "Собираем DDR test payload..."
	$(CC) $(CFLAGS) -Ttext=$(DDR_ADDR) $(PAYLOAD_SRC) -o payload.elf
	$(OBJCOPY) $(OBJCOPY_FLAGS) payload.elf payload.bin

	@echo "Делаем payload.hex0..."
	chmod +x ./bin-to-hex0.sh
	./bin-to-hex0.sh payload.bin payload.hex0

	@echo "Склеиваем boot.bin + payload.hex0..."
	cat boot.bin payload.hex0 > $@

$(WRAPPED_BIN): force $(YOUR_RAW_BIN)
	@echo "Оборачиваем в U-Boot image..."
	$(MKIMAGE) -A riscv -O u-boot -T standalone -C none \
	-a $(DDR_ADDR) -e $(DDR_ADDR) -n "DDR test" \
	-d $(YOUR_RAW_BIN) $@

$(FINAL_FLASH_IMG): force $(WRAPPED_BIN)
	@echo "Собираем образ для флешки..."
	dd if=/dev/zero of=$@ bs=1M count=4
	dd if=$(SPL_BIN) of=$@ conv=notrunc
	dd if=$(WRAPPED_BIN) of=$@ bs=1k seek=1024 conv=notrunc
	@echo "ГОТОВО: $(FINAL_FLASH_IMG)"

rebuild: clean all

clean:
	rm -f boot.elf boot.bin
	rm -f payload.elf payload.bin payload.hex0
	rm -f $(YOUR_RAW_BIN)
	rm -f $(WRAPPED_BIN)
	rm -f $(FINAL_FLASH_IMG)
