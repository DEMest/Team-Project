include config.mk

INTERMEDIATE_FILES = boot.elf boot.bin simon.elf simon.bin simon.hex0

all: $(YOUR_RAW_BIN)

$(YOUR_RAW_BIN): $(BOOT_SRC) $(PAYLOAD_SRC) $(FILES_HEX0) $(BOARD_HEADER) config.mk boards/$(BOARD).mk
	$(CC) $(CFLAGS) $(BOARD_CFLAGS) $(TEXT_FLAG)$(DDR_ADDR) $(BOOT_SRC) -o boot.elf
	$(OBJCOPY) -O binary boot.elf boot.bin
	$(CC) $(CFLAGS) $(BOARD_CFLAGS) $(TEXT_FLAG)$(DDR_ADDR) $(PAYLOAD_SRC) -o simon.elf
	$(OBJCOPY) -O binary simon.elf simon.bin
	chmod +x ./bin-to-hex0.sh
	./bin-to-hex0.sh simon.bin simon.hex0
	printf '\0' >> simon.hex0
	cat boot.bin simon.hex0 $(FILES_HEX0) > $@
	@echo "ГОТОВО: $@"
	@stat -c "Размер: %s bytes" $@
	@echo "BOARD=$(BOARD)"
	@echo "U-Boot raw: ext4load mmc 0:5 $(DDR_ADDR) $@; go $(DDR_ADDR)"

fullflash: $(YOUR_RAW_BIN)
ifeq ($(SUPPORTS_FULLFLASH),1)
	PAYLOAD=$(YOUR_RAW_BIN) WRAPPED=$(WRAPPED_BIN) FLASH=$(FULLFLASH_BIN) SPL=$(UBOOT_SPL_BIN) LOAD_ADDR=$(DDR_ADDR) IMAGE_NAME=$(UBOOT_IMAGE_NAME) python3 make_uboot_flash.py
	@echo "ГОТОВО FULLFLASH: $(FULLFLASH_BIN)"
else
	@echo "BOARD=$(BOARD) does not use fullflash. Use raw image: $(YOUR_RAW_BIN)"
endif

qemu:
	$(MAKE) BOARD=qemu_virt clean_tmp
	$(MAKE) BOARD=qemu_virt $(YOUR_RAW_BIN)
	qemu-system-riscv64 -M virt -bios image_qemu.bin -monitor stdio

prepare-files:
	cd files && ./prepare_files.sh

clean_tmp:
	rm -f $(INTERMEDIATE_FILES)

clean: clean_tmp
	rm -f image_simon_*.bin image_simon_work.bin image_qemu.bin simon_wrapped_*.img flash_me_*.bin

.PHONY: all fullflash qemu prepare-files clean clean_tmp
