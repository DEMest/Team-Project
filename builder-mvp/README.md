# Сборка для MVP
## Источники
За основу взяты:
* Проект [зимней школы](https://github.com/ylab-nsu/ws25-bootstrap)
* [fosslinux/live-bootstrap](https://github.com/fosslinux/live-bootstrap)

Для ориентировании в коде рекомендую использовать [RISC-V Assembler Cheat Sheet](https://projectf.io/posts/riscv-cheat-sheet/).

## Запуск
Были написаны два (в зависимости от вашей платформы) shell-скрипта для билда и запуска. Для ручной сборки предлагаю ознакомиться с их кодами.
> [!NOTE]
> Отличия в скриптах исключительно в приставках команд, которые у меня разные на двух системах. 
> Вполне возможно, что это я просто криво установил зависимости, поэтому если присущий вам скрипт не работает - попробуйте запустить другой. 

Также реализован Makefile как ещё один вариант сборки и запуска.

## Об образе
В загрузочном файле реализована тестовая конкатенация трёх стадий, где основной упор сделан на вторую - ядро simon.
```
image_payload.bin = boot ^ simon ^ payload
```
Остальные два файла были заимствованны из зимней школы: boot немного видоизменён для эстетики, а payload принимается за "третью стадию". Для более подробной информации обращайтесь к [parts.rst](https://github.com/DEMest/Team-Project/blob/feature/stage3/builder-mvp/parts.rst).

## Иные файлы
* [bin-to-hex0.sh](https://github.com/DEMest/Team-Project/blob/feature/stage3/builder-mvp/bin-to-hex0.sh) - перевод бинарника в формат hex0.
* [hex0.sh](https://github.com/DEMest/Team-Project/blob/feature/stage3/builder-mvp/hex0.sh) - перевод hex0 обратно в бинарник.
* [add_null.sh](https://github.com/DEMest/Team-Project/blob/feature/stage3/builder-mvp/add_null.sh) - добавление в конец файла нулевого символа для разделения конкатенации.
* [payload.hex0](https://github.com/DEMest/Team-Project/blob/feature/stage3/builder-mvp/payload.hex0) - "третья стадия", включённая в загрузочный образ и пример, как стоит оформлять файлы для инициализации. 
