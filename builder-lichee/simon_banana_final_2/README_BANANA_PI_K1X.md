# Banana Pi BPI-F3 / SpacemiT K1-X port

Эта версия предназначена для запуска через штатный boot chain платы:

ROM -> FSBL -> OpenSBI -> U-Boot -> image_simon_work.bin -> boot.S -> Simon

Linux, rootfs, kernel и initrd не нужны.

## Что изменено относительно QEMU-версии

* UART QEMU `0x10000000` заменён на Banana Pi UART `0xD4017000`.
* LSR для Banana Pi: offset `0x14`, RX ready `0x01`, TX idle `0x20`.
* Рабочая память Simon перенесена из QEMU-зоны `0x800xxxxx` в DDR-зону Banana Pi `0x120xxxxx` / `0x121xxxxx`.
* Heap перенесён с `0x84000000..0x88000000` на `0x16000000..0x1A000000`.
* M-mode CSR заменены на S-mode CSR: `mtvec/mepc/mcause/mtval/mscratch/mret` -> `stvec/sepc/scause/stval/sscratch/sret`.
* QEMU CLINT timer `0x200BFF8/0x2004000` отключён: на Banana Pi этот код нельзя трогать из payload через OpenSBI/U-Boot.
* SiSH читает UART polling'ом, без timer interrupt.
* `do` запускает пользовательские бинарники в U-mode, чтобы `ecall` попадал в обработчик Simon.
* Поддержан старый `exit` через `a7=80` и обычный Linux-style `exit` через `a7=93`.
* Поправлены `hex0`, `view`, backspace и сборка raw-образа.

## Сборка

По умолчанию используется clang/llvm-objcopy:

```bash
./build_banana.sh
```

Или вручную:

```bash
make clean
make TOOLCHAIN=clang
```

На выходе нужен файл:

```text
image_simon_work.bin
```

## Заливка на SD

Bootfs — это 5-й раздел SD-карты. Пример для `/dev/sdc5`:

```bash
sudo mkdir -p /mnt/bootfs
sudo mount /dev/sdc5 /mnt/bootfs
sudo cp image_simon_work.bin /mnt/bootfs/image_simon_work.bin
sync
sudo umount /mnt/bootfs
```

Если карта стала `/dev/sdb`, используй `/dev/sdb5`.

## Запуск вручную в U-Boot

Сначала желательно отключить watchdog:

```text
wdt dev watchdog@d4080000
wdt stop
```

Потом:

```text
ext4load mmc 0:5 0x10000000 image_simon_work.bin
go 0x10000000
```

## Autoboot

Сначала проверь ручной запуск. Если всё нормально:

```text
setenv bootcmd 'wdt dev watchdog@d4080000; wdt stop; if ext4load mmc 0:5 0x10000000 image_simon_work.bin; then go 0x10000000; fi'
setenv bootdelay 1
saveenv
```

## Быстрый тест в Simon

```text
ls
hex0 testA.hex0
do testA.bin
```

Также в образе лежат файлы:

```text
hex1.hex0
hex2.hex1
M0.hex2
testA.hex0
testB.hex1
testC.hex2
testD.M0
```
