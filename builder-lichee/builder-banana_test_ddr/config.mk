DDR_ADDR = 0x10000000

BOOT_SRC = src/boot.S
PAYLOAD_SRC = src/ddr_init.S

YOUR_RAW_BIN = image_simon_work.bin
SPL_BIN = u-boot-with-spl.bin
FINAL_FLASH_IMG = flash_me.bin

CROSS_COMPILE = riscv64-unknown-elf-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
MKIMAGE = mkimage
