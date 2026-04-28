#!/bin/bash
# elf2hex1.sh <file.elf>
# Генерирует hex1 шаблон из ELF файла.
# Байты прыжков остаются как есть — замени их на @label вручную.

set -e

ELF="$1"
[ -z "$ELF" ] && { echo "Использование: $0 <file.elf>"; exit 1; }
NAME=$(basename "$ELF" .elf)

echo "src $NAME.hex1"
echo ""

riscv64-unknown-elf-objdump -d "$ELF" | awk '
BEGIN { FS="\t" }

# Строка с меткой: "0000000000000000 <_start>:"
/^[0-9a-f]+ <[^>]+>:/ {
    match($0, /<([^>]+)>:/, m)
    lbl = m[1]
    gsub(/[+@].*/, "", lbl)
    if (lbl !~ /\$/) print ":" lbl
    next
}

# Строка с инструкцией (tab-separated)
NF >= 2 && $1 ~ /[0-9a-f]+:/ {
    raw = $2
    gsub(/ /, "", raw)

    inst = $3
    if (NF >= 4) inst = inst " " $4
    gsub(/^[ \t]+|[ \t]+$/, "", inst)
    gsub(/ <[^>]+>/, "", inst)   # убираем <symbol+0x..> из комментария

    # Разворачиваем байты: objdump даёт little-endian слово, нам нужны байты в порядке памяти
    n = length(raw)
    bytes = ""
    for (i = n-1; i >= 1; i -= 2)
        bytes = bytes substr(raw, i, 2) " "
    gsub(/ $/, "", bytes)

    printf "%-24s; %s\n", toupper(bytes), inst
}
'
