include config.mk

CFLAGS = -march=rv64gc -mabi=lp64d -nostdlib -ffreestanding
INTERMEDIATE_FILES = boot.elf boot.bin simon.elf simon.bin simon.hex0

all: $(YOUR_RAW_BIN)

$(YOUR_RAW_BIN): $(BOOT_SRC) $(PAYLOAD_SRC) $(FILES_HEX0)
	$(CC) $(CFLAGS) $(TEXT_FLAG)$(DDR_ADDR) $(BOOT_SRC) -o boot.elf
	$(OBJCOPY) -O binary boot.elf boot.bin
	$(CC) $(CFLAGS) $(TEXT_FLAG)$(DDR_ADDR) $(PAYLOAD_SRC) -o simon.elf
	$(OBJCOPY) -O binary simon.elf simon.bin
	chmod +x ./bin-to-hex0.sh
	./bin-to-hex0.sh simon.bin simon.hex0
	printf '\0' >> simon.hex0
	cat boot.bin simon.hex0 $(FILES_HEX0) > $@
	@echo "ГОТОВО: $@"
	@stat -c "Размер: %s bytes" $@
	@echo "U-Boot: ext4load mmc 0:5 $(DDR_ADDR) $@; go $(DDR_ADDR)"

qemu:
	$(MAKE) clean_tmp
	$(CC) -DQEMU $(CFLAGS) $(TEXT_FLAG)0x80000000 $(BOOT_SRC) -o boot.elf
	$(OBJCOPY) -O binary boot.elf boot.bin
	$(CC) -DQEMU $(CFLAGS) $(TEXT_FLAG)0x80000000 $(PAYLOAD_SRC) -o simon.elf
	$(OBJCOPY) -O binary simon.elf simon.bin
	./bin-to-hex0.sh simon.bin simon.hex0
	printf '\0' >> simon.hex0
	cat boot.bin simon.hex0 $(FILES_HEX0) > image_qemu.bin
	qemu-system-riscv64 -M virt -bios image_qemu.bin -monitor stdio

prepare-files:
	cd files && ./prepare_files.sh

clean_tmp:
	rm -f $(INTERMEDIATE_FILES)

clean: clean_tmp
	rm -f $(YOUR_RAW_BIN) image_qemu.bin

.PHONY: all qemu prepare-files clean clean_tmp
