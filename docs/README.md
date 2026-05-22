# Документация проекта bootstrap

## Команда

Соответствие GitHub-ников именам студентов:

| GitHub | Имя |
|---|---|
| [DEMest](https://github.com/DEMest) | Даниил Смолин |
| [alwenwhy](https://github.com/alwenwhy) | Юрий Пивкин |
| [ViktorTum](https://github.com/ViktorTum) | Виктор Тумилевич |
| [Rakdat](https://github.com/Rakdat) | Максим Токарев |

## Репозиторий

Публичный Git-репозиторий проекта: <https://github.com/DEMest/Trusted-environment-on-RISCV>

## Доска задач

Issues и Project-доска проекта ведутся в том же репозитории:

- Issues: <https://github.com/DEMest/Trusted-environment-on-RISCV/issues>
- Pull Requests: <https://github.com/DEMest/Trusted-environment-on-RISCV/pulls>

## Артефакты проекта

### Документация (`docs/`)

| Артефакт | Описание |
|---|---|
| [SAD.md](SAD.md) | Software Architecture Document — архитектура трёхстадийной загрузки, карта памяти, описание builder-ов. |
| [SRS_bootstrap(ENG).md](SRS_bootstrap%28ENG%29.md) | Software Requirements Specification (англ.) — функциональные и нефункциональные требования, use-cases, критерии приёмки. |
| [SRS_bootstrap(RU).md](SRS_bootstrap%28RU%29.md) | SRS (рус.) — русская версия требований. |
| [Vision(ENG).md](Vision%28ENG%29.md) | Vision Document (англ.) — концепция, цели, заинтересованные стороны, roadmap. |
| [Vision(RU).md](Vision%28RU%29.md) | Vision (рус.) — русская версия. |
| [Project-Schedule.md](Project-Schedule.md) | План работ и ключевые даты. |

### Исходники и сборки (`/`)

| Каталог | Содержание |
|---|---|
| `builder-mvp/` | MVP-сборка: `boot` (stage 1) + `simon` (stage 2) + hex0-payload, запуск в QEMU `virt`. |
| `builder-hex1/` | MVP + встроенный в `simon` hex1-компилятор, набор интеграционных тестов `pytest + pexpect`. |
| `builder-hex2/` | Активная разработка: hex2 + текущий milestone — запуск **M0** (live-bootstrap). |
| `builder-lichee/` | Сборка под LicheePi 4A (SRAM-база `0xFFE0000000`). |
| `builder-syscall/` | Изолированный снимок с процессной моделью (`create_process`, `switch_context`). |
| `presentation/` | Слайды защит и промежуточных отчётов. |

### Внешние ориентиры

- Дорожная карта стадий: [live-bootstrap `parts.rst`](https://github.com/fosslinux/live-bootstrap/blob/master/parts.rst).
- Базовый stage 1 заимствован у [ws25-bootstrap](https://github.com/ylab-nsu/ws25-bootstrap).
