# ws25-bootstrap

## Сборка файлов stage1.S и payload.S

для wsl:

```
export CROSS_COMPILE=riscv64-unknown-elf-
```

для linux:

```
export CROSS_COMPILE=riscv64-elf-
```

## Сборка вручную

```
${CROSS_COMPILE}gcc -march=rv64gc\
			   -nostdlib\
			   -ffreestanding\
			   -Ttext 0\
			   ./src/stage1.S -o stage1.elf
```

После компановке, используя команду readelf -h, мы можем увидеть

```
ELF Header:
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF64
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              EXEC (Executable file)
  Machine:                           RISC-V
  Version:                           0x1
  Entry point address:               0x0
  Start of program headers:          64 (bytes into file)
  Start of section headers:          5264 (bytes into file)
  Flags:                             0x5, RVC, double-float ABI
  Size of this header:               64 (bytes)
  Size of program headers:           56 (bytes)
  Number of program headers:         1
  Size of section headers:           64 (bytes)
  Number of section headers:         6
  Section header string table index: 5
```

Собрав исполняемый файл, преобразуем его в бинарный образ

```
${CROSS_COMPILE}objcopy -O binary stage1.elf stage1.bin
```

Далее сконкатенируем 'stage1.bin' и код полезной нагрузки

```
cat stage1.bin <payload>.hex0 > image_<platform>.bin
```

| > здесь payload - файл полезной нагруки, программа, которая сработает при запуске нашего образа.