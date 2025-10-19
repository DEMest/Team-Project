## Источники
За основу взят проект [зимней школы](https://github.com/ylab-nsu/ws25-bootstrap), откуда взяты скрипты shell для сборки программы на hex0, а также код boot.S, запускающий весь образ.
Для ориентировании в коде рекомендую использовать [RISC-V Assembler Cheat Sheet](https://projectf.io/posts/riscv-cheat-sheet/).

## Запуск
Для тестирования образа достаточно взять готовый файл image_qemu.bin и запустить у себя командой
```
qemu-system-riscv64 -M virt -bios image_qemu.bin
```  
и для дальнейшей работы выбрать View -> serial0 (или Ctrl+Alt+2).

## Что вообще образ делает
Реализован ввод-вывод через UART, позволяющий пользователю взаимедействовать с образом. 
Написано своеобразное `echo` при вводе, а так же различается ключевое слово `shutdown`.

## Сборка своими руками
Образ выглядит как конкатенация бинарника кода boot.S и файла simon.S в hex0 формате:
```
image_qemu.bin = (bin^hex0)
```
1. Оба файла собираются в .elf
```
riscv64-unknown-elf-gcc -march=rv64gc -nostdlib -ffreestanding -Ttext=0x80000000 src/boot.S -o boot.elf
riscv64-unknown-elf-gcc -march=rv64gc -nostdlib -ffreestanding -Ttext=0x80000000 src/simon.S -o simon.elf
```
3. Из .elf мы переделываем эти файлы в .bin
```
riscv64-unknown-elf-objcopy -O binary boot.elf boot.bin
riscv64-unknown-elf-objcopy -O binary simon.elf simon.bin
```
5. Программу (в нашем случае simon.bin), которую будет собирать boot, переводим в .hex0 shell скриптом
```
./bin-to-hex0.sh simon.bin simon.hex0
``` 
> [!NOTE]
> В файле .hex0 можно добавлять комментарии, как это реализовано у зимней школы.
4. Конкатенируем полученные два файла в образ
```
cat boot.bin simon.hex0 > image_qemu.bin
```
