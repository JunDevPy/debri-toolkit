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
  echo "[!] Запускать от root: sudo ./40_ir_boot.sh"
  exit 1
fi

IR_DIR="${IR_DIR:-/root/ir}"

if [[ -n "${IR_RUN_DIR:-}" ]]; then
  OUT_DIR="$IR_RUN_DIR"
else
  OUT_DIR="$IR_DIR/run_$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUT_DIR"
LOG="$OUT_DIR/40-boot.log"

{
  echo "=== SCRIPT: 40_ir_boot.sh ==="
  date
  echo

  echo "=== FIRMWARE TYPE ==="
  if [[ -d /sys/firmware/efi ]]; then
    echo "EFI/UEFI"
  else
    echo "BIOS/Legacy or EFI variables unavailable"
  fi
  echo

  echo "=== EFIBOOTMGR ==="
  if command -v efibootmgr >/dev/null 2>&1 && [[ -d /sys/firmware/efi ]]; then
    efibootmgr -v || true
  else
    echo "efibootmgr unavailable or not EFI"
  fi
  echo

  echo "=== SECURE BOOT STATE ==="
  if command -v mokutil >/dev/null 2>&1; then
    mokutil --sb-state || true
    echo
    echo "=== MOK ENROLLED KEYS ==="
    mokutil --list-enrolled 2>/dev/null | head -n 100 || true
  else
    echo "mokutil unavailable"
  fi
  echo

  echo "=== KERNEL CMDLINE ==="
  cat /proc/cmdline || true
  echo

  echo "=== /boot listing ==="
  ls -l /boot || true
  echo

  echo "=== /boot files with mtime ==="
  find /boot -type f -printf '%p | size=%s mtime=%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null \
    | head -n 300 || true
  echo

  echo "=== EFI SYSTEM PARTITION ==="
  if mountpoint -q /boot/efi 2>/dev/null; then
    find /boot/efi -type f -name '*.efi' \
      -printf '%p | size=%s mtime=%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null || true
  else
    echo "/boot/efi not mounted"
  fi
  echo

  echo "=== FSTAB BOOT/EFI ==="
  grep -E '/boot|efi' /etc/fstab 2>/dev/null || true
  echo

  echo "=== GRUB CFG SUSPICIOUS LINES ==="
  if [[ -f /boot/grub/grub.cfg ]]; then
    grep -E '^[[:space:]]*(linux|initrd|insmod|source)' /boot/grub/grub.cfg \
      | head -n 200 || true
  else
    echo "/boot/grub/grub.cfg not found"
  fi
  echo

  echo "=== GRUB CUSTOM/DEFAULT ==="
  grep -R . /etc/default/grub /etc/grub.d/40_custom /etc/grub.d/41_custom 2>/dev/null || true
  echo

  echo "=== DMI BIOS ==="
  if command -v dmidecode >/dev/null 2>&1; then
    dmidecode -t bios | head -n 120 || true
  else
    echo "dmidecode unavailable"
  fi
  echo

  echo "=== FWUPD SECURITY ==="
  if command -v fwupdmgr >/dev/null 2>&1; then
    fwupdmgr security --force 2>/dev/null || fwupdmgr security 2>/dev/null || true
  else
    echo "fwupdmgr unavailable"
  fi

} 2>&1 | tee "$LOG"

echo "[+] Saved: $LOG"
