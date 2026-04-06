# Сборка для MVP

## Источники
За основу взяты:
* Проект [зимней школы](https://github.com/ylab-nsu/ws25-bootstrap)
* [fosslinux/live-bootstrap](https://github.com/fosslinux/live-bootstrap)

Для ориентирования в коде рекомендую использовать [RISC-V Assembler Cheat Sheet](https://projectf.io/posts/riscv-cheat-sheet/).

## Зависимости

* `riscv64-unknown-elf-gcc` (Linux/WSL) или `riscv-none-elf-gcc` (Windows)
* `qemu-system-riscv64`
* `xxd`

## Запуск

**WSL / Linux:**
```bash
make build-and-run  # сборка + запуск
make                # только сборка
make run            # только запуск
```

**Windows (PowerShell):**
```powershell
wsl make build-and-run
wsl make
wsl make run
```

> [!NOTE]
> Makefile использует Linux-утилиты (`chmod`, `stat`, `rm`), поэтому на Windows необходим WSL.
> Команда `wsl make` запускает сборку в WSL прямо из PowerShell.

Выход из QEMU: `Ctrl+A`, затем `X`.

### Переменные

| Переменная | По умолчанию | Описание |
|---|---|---|
| `CROSS_COMPILE` | `riscv64-unknown-elf-` | Префикс компилятора |
| `FS_FILES` | `payload.hex0` | Файлы, упаковываемые в образ |
| `OUTPUT_IMAGE` | `image_payload.bin` | Имя выходного образа |

Пример с кастомными файлами ФС:
```bash
make FS_FILES="stage3.hex0 другой.hex0"
```

## Об образе

```
image_payload.bin = boot.bin + simon.hex0 + <файлы ФС>
```

* **boot** — загрузчик (stage 1): декодирует `simon.hex0` из образа и передаёт управление simon. Заимствован из зимней школы, слегка изменён.
* **simon** — минимальное ядро (stage 2): инициализирует файловую систему из данных образа, умеет компилировать hex0 и исполнять файлы.
* **payload** — тестовая stage 3: выводит "Hello, World!" и уходит в цикл.

Подробнее: [parts.rst](./parts.rst)

![Демонстрация работы](./demo.png)

## Формат файлов ФС

Каждый файл для упаковки в образ должен начинаться со строки `src <имя файла>` и заканчиваться нулевым байтом:

```
src myfile.hex0
<hex0 содержимое>
\0
```

Пример: [payload.hex0](./payload.hex0)

## Утилиты

* `bin-to-hex0.sh` — перевод бинарника в формат hex0
* `hex0.sh` — перевод hex0 обратно в бинарник
* `add_null.sh` — добавление нулевого байта в конец файла
