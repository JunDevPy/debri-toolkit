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

usage() {
  cat <<'EOF'
Использование:

  sudo ./75_ir_export.sh [user] [dest_dir]

По умолчанию:
  user = SUDO_USER (тот, кто запустил sudo), иначе USER
  dest = домашний каталог этого пользователя

Примеры:

  sudo ./75_ir_export.sh
  sudo ./75_ir_export.sh antonis
  sudo ./75_ir_export.sh antonis /home/antonis/Reports

Что делает:
  - находит последний архив /root/ir/ir_report_*.tar.gz;
  - копирует его в целевой каталог;
  - создаёт рядом .sha256 с относительным путём (чтобы sha256sum -c работал в новом каталоге);
  - меняет владельца на целевого пользователя и ставит читаемые права.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $EUID -ne 0 ]]; then
  echo "[!] Запускать от root: sudo ./75_ir_export.sh"
  exit 1
fi

TARGET_USER="${1:-${SUDO_USER:-${USER:-}}}"
DEST_DIR="${2:-}"

if [[ -z "$TARGET_USER" ]]; then
  echo "[!] Не удалось определить целевого пользователя."
  usage
  exit 1
fi

if ! getent passwd "$TARGET_USER" >/dev/null 2>&1; then
  echo "[!] Пользователь не найден: $TARGET_USER"
  exit 1
fi

TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_GROUP=$(id -gn "$TARGET_USER" 2>/dev/null || echo "$TARGET_USER")

if [[ -z "$DEST_DIR" ]]; then
  DEST_DIR="$TARGET_HOME"
fi

if [[ ! -d "$DEST_DIR" ]]; then
  echo "[!] Каталог назначения не существует: $DEST_DIR"
  exit 1
fi

shopt -s nullglob
reports=( "$IR_DIR"/ir_report_*.tar.gz )
shopt -u nullglob

if (( ${#reports[@]} == 0 )); then
  echo "[!] В $IR_DIR не найдено архивов ir_report_*.tar.gz"
  echo "    Сначала выполните: sudo ./ir_check.sh pack"
  exit 1
fi

ARC=$(printf '%s\n' "${reports[@]}" | sort | tail -n 1)
ARC_NAME=$(basename "$ARC")

echo "[*] Найден отчёт: $ARC"
echo "[*] Целевой пользователь: $TARGET_USER"
echo "[*] Каталог назначения: $DEST_DIR"
echo

cp -f "$ARC" "$DEST_DIR/$ARC_NAME" || { echo "[!] Ошибка копирования архива"; exit 1; }

# Пересоздаём .sha256 с относительным путём, чтобы проверка работала в новом каталоге
( cd "$DEST_DIR" && sha256sum "$ARC_NAME" > "$ARC_NAME.sha256" ) \
  || { echo "[!] Ошибка создания .sha256"; exit 1; }

chown "$TARGET_USER:$TARGET_GROUP" "$DEST_DIR/$ARC_NAME" "$DEST_DIR/$ARC_NAME.sha256" || true
chmod 644 "$DEST_DIR/$ARC_NAME" "$DEST_DIR/$ARC_NAME.sha256" || true

echo "[+] Скопировано:"
ls -l "$DEST_DIR/$ARC_NAME" "$DEST_DIR/$ARC_NAME.sha256"
echo

echo "[*] Проверка контрольной суммы копии:"
( cd "$DEST_DIR" && sha256sum -c "$ARC_NAME.sha256" ) || true

echo
echo "[!] ВНИМАНИЕ: архив содержит диагностические данные (имена пользователей,"
echo "    пути, сетевые адреса, отпечатки ключей и т.п.)."
echo "    Не оставляй его в общедоступном месте и удали после передачи:"
echo "      rm -f \"$DEST_DIR/$ARC_NAME\" \"$DEST_DIR/$ARC_NAME.sha256\""
