#!/usr/bin/env bash
# Copyright (c) [2026] [Глазов Андрей / JunDevPy]. All rights reserved.
# Original source: [https://github.com/JunDevPy/debri-toolkit]
# License: MIT + Commons Clause
#
# - Исходный код открыт, доработка разрешена / Source code is open, modifications allowed.
# - Продажа и перепродажа скрипта или его модификаций ЗАПРЕЩЕНА всем, кроме правообладателя /
#   Sale and resale of the script or its modifications is PROHIBITED for anyone except the copyright holder.
# - При использовании в любых платных или бесплатных системах ОБЯЗАТЕЛЬНО явное указание автора /
#   Explicit attribution to the author is MANDATORY when used in any paid or free systems.
set -u
umask 077
export LC_ALL=C

IR_DIR="${IR_DIR:-/root/ir}"
LATEST="$IR_DIR/latest"

if [[ ! -e "$LATEST" ]]; then
  echo "[!] Нет symlink: $LATEST"
  echo "Сначала запусти проверки: sudo ./ir_check.sh all"
  exit 1
fi

TARGET="$(readlink -f "$LATEST")"

if [[ ! -d "$TARGET" ]]; then
  echo "[!] $TARGET не является каталогом."
  exit 1
fi

OUT="$IR_DIR/ir_report_$(date +%Y%m%d-%H%M%S).tar.gz"

tar -C "$(dirname "$TARGET")" -czf "$OUT" "$(basename "$TARGET")"
chmod 600 "$OUT"

sha256sum "$OUT" > "$OUT.sha256"
chmod 600 "$OUT.sha256"

echo "[+] Архив создан: $OUT"
echo "[+] SHA256: $OUT.sha256"
