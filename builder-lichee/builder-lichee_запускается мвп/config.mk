DEFINES = -DLICHEE_PI_4A

BOOT_SRC = src/boot.S
PAYLOAD_SRC = src/simon_yra.S

YOUR_RAW_BIN = image_simon_work.bin
SPL_BIN = u-boot-with-spl.bin
FINAL_FLASH_IMG = flash_me.bin

DDR_ADDR = 0x40000000
PAYLOAD_LOAD_ADDR = 0x40010000
SRAM_BASE_FOR_LINK = 0xFFE0000000

CROSS_COMPILE = riscv64-unknown-elf-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
MKIMAGE = mkimage
