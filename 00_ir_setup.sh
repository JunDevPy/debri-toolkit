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
  echo "[!] Запускать от root: sudo ./00_ir_setup.sh"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

IR_DIR="${IR_DIR:-/root/ir}"
STATE_DIR="$IR_DIR/state"
PKG_STATE="$STATE_DIR/setup_installed_packages.txt"

mkdir -p "$IR_DIR" "$STATE_DIR"
chmod 700 "$IR_DIR"
chmod 700 "$STATE_DIR"

touch "$PKG_STATE"
chmod 600 "$PKG_STATE"

PKGS=(
  debsums
  lsof
  psmisc
  efibootmgr
  mokutil
  fwupd
  binutils
  usbutils
  pciutils
  dmidecode
  libcap2-bin
  ca-certificates
)

EXTRA=()
if [[ "${1:-}" == "--with-scanners" ]]; then
  EXTRA=(
    rkhunter
    chkrootkit
    lynis
  )
fi

is_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "ok installed"
}

install_packages() {
  local -a pkgs=("$@")

  if (( ${#pkgs[@]} == 0 )); then
    return 0
  fi

  local -a new_pkgs=()
  local p

  for p in "${pkgs[@]}"; do
    if ! is_installed "$p"; then
      new_pkgs+=("$p")
    fi
  done

  echo "[*] Установка: ${pkgs[*]}"
  apt-get install -y --no-install-recommends "${pkgs[@]}" \
    || echo "[!] Часть пакетов не установилась."

  for p in "${new_pkgs[@]}"; do
    if is_installed "$p"; then
      echo "$p" >> "$PKG_STATE"
    fi
  done

  if (( ${#new_pkgs[@]} > 0 )); then
    sort -u "$PKG_STATE" -o "$PKG_STATE"
    chmod 600 "$PKG_STATE"
  fi
}

echo "[*] Обновление списка пакетов..."
apt-get update -qq || echo "[!] apt-get update завершился с ошибкой, продолжаю."

install_packages "${PKGS[@]}"

if (( ${#EXTRA[@]} > 0 )); then
  install_packages "${EXTRA[@]}"
fi

cat > "$IR_DIR/README.txt" <<'EOF'
Каталог логов проверки.

Логи создаются скриптами:
  10_ir_basic.sh
  15_ir_anomalies.sh
  16_ir_ssh_audit.sh
  20_ir_integrity.sh
  30_ir_modules.sh
  40_ir_boot.sh
  50_ir_network.sh
  60_ir_scanners.sh
  80_ir_audit_ssh_rules.sh

Контроллер:
  ir_check.sh

Очистка:
  90_ir_cleanup.sh

Последний запуск:
  /root/ir/latest

Состояние установки:
  /root/ir/state/setup_installed_packages.txt
EOF

chmod 600 "$IR_DIR/README.txt"

echo "[+] Подготовка завершена."
echo "[+] Каталог логов: $IR_DIR"
echo "[+] Состояние: $PKG_STATE"
