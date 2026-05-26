# Banana Pi BPI-F3 / SpacemiT K1-X
# U-Boot:
#   ext4load mmc 0:5 0x10000000 image_simon_work.bin
#   go 0x10000000
DDR_ADDR = 0x10000000
BOOT_SRC = src/boot.S
PAYLOAD_SRC = src/simon.S
YOUR_RAW_BIN = image_simon_work.bin
FILES_HEX0 ?= files.pl

TOOLCHAIN ?= clang
CROSS_COMPILE ?= riscv64-unknown-elf-

ifeq ($(TOOLCHAIN),clang)
CC = clang --target=riscv64-unknown-elf
OBJCOPY = llvm-objcopy
TEXT_FLAG = -Wl,-Ttext=
else
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
TEXT_FLAG = -Ttext=
endif
