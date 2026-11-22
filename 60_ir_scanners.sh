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

if [[ $EUID -ne 0 ]]; then
  echo "[!] Запускать от root: sudo ./60_ir_scanners.sh"
  exit 1
fi

IR_DIR="${IR_DIR:-/root/ir}"

if [[ -n "${IR_RUN_DIR:-}" ]]; then
  OUT_DIR="$IR_RUN_DIR"
else
  OUT_DIR="$IR_DIR/run_$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUT_DIR"
LOG="$OUT_DIR/60-scanners.log"

{
  echo "=== SCRIPT: 60_ir_scanners.sh ==="
  date
  echo

  echo "=== RKHUNTER ==="
  if command -v rkhunter >/dev/null 2>&1; then
    rkhunter --update || true
    rkhunter --check --sk || true
  else
    echo "rkhunter not installed"
  fi
  echo

  echo "=== CHKROOTKIT ==="
  if command -v chkrootkit >/dev/null 2>&1; then
    chkrootkit || true
  else
    echo "chkrootkit not installed"
  fi
  echo

  echo "=== LYNIS ==="
  if command -v lynis >/dev/null 2>&1; then
    lynis audit system --quick --no-colors || true
  else
    echo "lynis not installed"
  fi

} 2>&1 | tee "$LOG"

echo "[+] Saved: $LOG"
