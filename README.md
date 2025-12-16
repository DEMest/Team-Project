# bootstrap

- Цели и план проекта лежат в папке 'presentation/'

- [SRS - Требования к системе](docs/SRS_bootstrap(ENG).md)
- [Project Schedule](docs/Project-Schedule.md)
- [Vision](docs/Vision(ENG).md)

- Исходные файлы лежат в папке builder/

## Documentation Package (Responsible: Даниил)
- [x] Project presentation
- [x] Software Requirements Specification (SRS)  
- [x] Project Schedule 
- [x] Vision Document 
- [ ] Семестровая презентация

## first steps

- [x] Develop the first RISC-V program for QEMU - Юра
- [x] Run stage1 on LicheePi 4A - Витя
- [x] Implement a system call for the virtual machine (QEMU) - Юра
- [x] Implement a system call for LicheePi - Витя

### Build (Витя)

- [x] Добавить `Makefile` для сборки/конвертации в hex0/сборки итогового образа.
- [x] Добавить `README.md` с инструкциями по сборке/запуску.

### Kernel (Юра)

- [x] Переписать ядро и добавить обработку паники (kernel panic) с возможностью восстановления.
- [x] Добавить команды `reboot`, `debug` (вызывает panic). 
- [x] Улучшить формат/информативность вывода (например, `[BOOTED]: ...`).

### Input (Даниил, Юра)

- [x] Реализован "канонический" ввод строки для UART-CLI: символы накапливаются в буфер до нажатия Enter, с поддержкой редактирования.
- [x] Добавить поддержку Backspace в `simon.S`.
- [x] Дополнительные правки по вводу.

### Memory (Максим)

- [x] Реализовать постраничный аллокатор `alloc_page` из области `FREE_RAM`.

### Utils (Юра)

- [x] Добавить утилиты для строк/памяти: `strlen`, `strcmp`, `cmdcmp`, `memset`, `memcpy`.
- [x] Добавить `puth` для печати чисел в hex-формате.

### Processes (Юра)

- [x] Добавить концепцию списка процессов.
- [x] Реализовать `create_process` (создание процесса: выделение памяти + инициализация контекста).
- [x] Реализовать `switch_context` (переключение контекста с сохранением всех регистров).
- [x] Добавить тестовые процессы `test_a` и `test_b` (поочередно печатают `A` и `B` и переключают друг друга).
- [ ] Добавить возможность запускать процесс делающий системный вызов и передавающий управление обратно ядру на Qemu.

### Platform (Витя)

- [x] Поддержка Lichee Pi 4A: `builder-lichee`, определение платформы и выбор правильного UART base address.
- [x] Добавить утилиту для Arduino Nano для отладки UART.
- [ ] Запустить отдельный процесс печатающий `hello world` на Lichee Pi 4A.
