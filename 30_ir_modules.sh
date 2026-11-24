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
  echo "[!] Запускать от root: sudo ./30_ir_modules.sh"
  exit 1
fi

IR_DIR="${IR_DIR:-/root/ir}"

if [[ -n "${IR_RUN_DIR:-}" ]]; then
  OUT_DIR="$IR_RUN_DIR"
else
  OUT_DIR="$IR_DIR/run_$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUT_DIR"
LOG="$OUT_DIR/30-modules.log"

{
  echo "=== SCRIPT: 30_ir_modules.sh ==="
  date
  echo

  echo "=== KERNEL VERSION ==="
  uname -r
  echo

  echo "=== KERNEL TAINT ==="
  cat /proc/sys/kernel/tainted || true
  echo

  echo "=== MODULE SIGNATURE ENFORCE / LOCKDOWN ==="
  cat /sys/module/module/parameters/sig_enforce 2>/dev/null || true
  cat /sys/kernel/security/lockdown 2>/dev/null || true
  echo

  echo "=== MODPROBE SYSCTL ==="
  sysctl kernel.modprobe kernel.modules_disabled 2>/dev/null || true
  echo

  echo "=== LSMOD DETAILS ==="
  for m in $(lsmod | awk 'NR>1{print $1}'); do
    f=$(modinfo -F filename "$m" 2>/dev/null || true)
    s=$(modinfo -F signer "$m" 2>/dev/null || true)
    pkg=""

    if [[ -n "$f" && -e "$f" ]]; then
      rf="$(realpath "$f" 2>/dev/null || echo "$f")"
      pkg="$(dpkg -S "$rf" 2>/dev/null || true)"
    fi

    echo "$m | file=$f | signer=$s | pkg=$pkg"
  done
  echo

  echo "=== DPKG VERIFY KERNEL PACKAGES ==="
  dpkg -V "linux-image-$(uname -r)" 2>/dev/null || true
  dpkg -V "linux-modules-$(uname -r)" 2>/dev/null || true
  echo

  echo "=== DMESG MODULE/SIGNATURE ==="
  dmesg -T 2>/dev/null \
    | grep -iE 'module verification|lockdown|signature|module.*failed' \
    | tail -n 150 || true
  echo

  echo "=== MODULE FILES OUTSIDE /lib/modules ==="
  find /tmp /var/tmp /dev/shm /root /home /opt /srv /usr/local \
    -type f \( -name '*.ko' -o -name '*.ko.*' \) -ls 2>/dev/null || true
  echo

  echo "=== DKMS STATUS ==="
  dkms status 2>/dev/null || true
  echo

  echo "=== MODULE AUTOLOAD CONFIG ==="
  grep -RniE '^[^#]*install ' \
    /etc/modprobe.d /usr/lib/modprobe.d /lib/modprobe.d 2>/dev/null \
    | head -n 200 || true

  cat /etc/modules-load.d/* /usr/lib/modules-load.d/* 2>/dev/null \
    | grep -v '^#' | head -n 200 || true
  echo

  echo "=== RECENTLY MODIFIED MODULE FILES ==="
  find /lib/modules -type f \( -name '*.ko' -o -name '*.ko.*' \) -mtime -90 \
    -printf '%p | size=%s mtime=%TY-%Tm-%Td %TH:%TM\n' 2>/dev/null \
    | head -n 500 || true
  echo

  echo "=== /lib/modules updates/extra ==="
  ls -lR "/lib/modules/$(uname -r)/updates" 2>/dev/null || true
  ls -lR "/lib/modules/$(uname -r)/extra" 2>/dev/null || true

} 2>&1 | tee "$LOG"

echo "[+] Saved: $LOG"
