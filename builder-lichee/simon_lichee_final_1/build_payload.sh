#!/bin/bash

riscv-none-elf-gcc -mabi=lp64d -march=rv64gc -nostdlib -ffreestanding -Ttext=0x80100400 src/payload.S -o payload.elf
riscv-none-elf-objcopy -O binary payload.elf payload.bin
./bin-to-hex0.sh payload.bin payload.hex0
echo "src payload.hex0" | cat - payload.hex0 > /tmp/p.hex0 && mv /tmp/p.hex0 payload.hex0
./add_null.sh payload.hex0