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
  echo "[!] Запускать от root: sudo ./10_ir_basic.sh"
  exit 1
fi

IR_DIR="${IR_DIR:-/root/ir}"

if [[ -n "${IR_RUN_DIR:-}" ]]; then
  OUT_DIR="$IR_RUN_DIR"
else
  OUT_DIR="$IR_DIR/run_$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUT_DIR"
LOG="$OUT_DIR/10-basic.log"

{
  echo "=== SCRIPT: 10_ir_basic.sh ==="
  date
  echo

  echo "=== DATE/RELEASE ==="
  date
  uname -a
  cat /etc/os-release 2>/dev/null || true
  hostnamectl || true
  echo

  echo "=== PID1 / INIT ==="
  readlink -f /proc/1/exe || true
  tr '\0' '\n' < /proc/1/environ 2>/dev/null \
    | grep -E '^LD_(PRELOAD|AUDIT|LIBRARY_PATH)=' \
    || echo "no suspicious LD_PRELOAD/LD_AUDIT/LD_LIBRARY_PATH in PID 1"
  cat /proc/sys/kernel/core_pattern 2>/dev/null || true
  echo

  echo "=== UPTIME / WHO / LAST ==="
  uptime || true
  who || true
  w || true
  last -x | head -n 80 || true
  echo

  echo "=== PROCESSES TREE ==="
  ps -eo pid,ppid,user,stat,lstart,args --forest | tail -n 400 || true
  echo

  echo "=== TOP CPU PROCESSES ==="
  ps -eo pid,user,pcpu,pmem,etime,args --sort=-pcpu | head -n 30 || true
  echo

  echo "=== NETWORK LISTEN ==="
  ss -tulpn || true
  echo

  echo "=== NETWORK ESTABLISHED ==="
  ss -tnp | head -n 200 || true
  echo

  echo "=== IP ADDR / ROUTE / NEIGH ==="
  ip addr || true
  ip route || true
  ip neigh || true
  echo

  echo "=== DNS / HOSTS ==="
  cat /etc/resolv.conf 2>/dev/null || true
  grep -v '^#' /etc/hosts 2>/dev/null || true
  echo

  echo "=== USERS / GROUPS ==="
  getent passwd \
    | awk -F: '$3==0 || $7 ~ /(bash|sh|zsh|fish)$/ {print $1,$3,$6,$7}' \
    || true

  getent group sudo wheel docker lxd libvirt kvm disk input plugdev \
    | awk -F: '{print $1, $4}' \
    || true
  echo

  echo "=== SSH AUTHORIZED_KEYS ==="
  find /root /home -type f -name authorized_keys -ls 2>/dev/null || true
  ls -lR /root/.ssh /home/*/.ssh 2>/dev/null || true
  echo

  echo "=== RUNNING SERVICES ==="
  systemctl list-units --type=service --state=running --no-pager || true
  echo

  echo "=== TIMERS ==="
  systemctl list-timers --all --no-pager | head -n 100 || true
  echo

  echo "=== ENABLED UNIT FILES ==="
  systemctl list-unit-files --state=enabled --no-pager | head -n 150 || true
  echo

  echo "=== KERNEL MODULES ==="
  lsmod || true
  echo

  echo "=== USB ==="
  lsusb -tv 2>/dev/null || true
  echo

  echo "=== PCI ==="
  lspci -nnk 2>/dev/null | head -n 120 || true
  echo

  echo "=== DMESG TAIL ==="
  dmesg -T | tail -n 150 || true

} 2>&1 | tee "$LOG"

echo "[+] Saved: $LOG"
