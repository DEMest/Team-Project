# config.mk — настройки проекта

# Адрес загрузки в DDR
DDR_ADDR = 0x40000000


# Исходные файлы (порядок важен, как в оригинальном правиле)
BOOT_SRC = src/boot.S
PAYLOAD_SRC = src/ddr_init.S

# Имя выходного "сырого" бинарника
YOUR_RAW_BIN = image_simon_work.bin

# Имя SPL бинарника от U-Boot
SPL_BIN = u-boot-with-spl.bin

# Итоговый образ для прошивки
FINAL_FLASH_IMG = flash_me.bin

# Утилиты
CROSS_COMPILE = riscv64-unknown-elf-
CC = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
MKIMAGE = mkimage
