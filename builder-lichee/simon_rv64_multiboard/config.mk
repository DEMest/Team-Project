# ============================================================
# Simon multi-board config
#
# To port Simon to another RISC-V board, do NOT edit src/*.S.
# Add two files instead:
#   boards/<new_board>.mk   - build/load/fullflash settings
#   boards/<new_board>.h    - UART, memory map, trap mode, watchdog
# Then build with:
#   make BOARD=<new_board>
# ============================================================

BOARD ?= lichee_th1520_fullflash
include boards/$(BOARD).mk

BOOT_SRC := src/boot.S
PAYLOAD_SRC := src/simon.S
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

CFLAGS = -march=rv64gc -mabi=lp64d -nostdlib -ffreestanding
BOARD_CFLAGS = -include $(BOARD_HEADER)
