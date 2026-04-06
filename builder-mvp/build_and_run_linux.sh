#!/bin/bash

set -e

echo "--- Compiling ELF files ---"
riscv64-unknown-elf-gcc -march=rv64gc -nostdlib -ffreestanding -Ttext=0x80000000 src/boot.S -o boot.elf
riscv64-unknown-elf-gcc -march=rv64gc -nostdlib -ffreestanding -Ttext=0x80000000 src/simon.S -o simon.elf

echo "--- Converting to BIN ---"
riscv64-unknown-elf-objcopy -O binary boot.elf boot.bin
riscv64-unknown-elf-objcopy -O binary simon.elf simon.bin

echo "--- Generating hex0 ---"
chmod +x ./bin-to-hex0.sh
./bin-to-hex0.sh simon.bin simon.hex0
./add_null.sh simon.hex0

echo "--- Creating final image ---"
cat boot.bin simon.hex0 payload.hex0 payload.hex0 > image_payload.bin

echo "--- Starting QEMU ---"
qemu-system-riscv64 -M virt -bios image_payload.bin -monitor stdio
