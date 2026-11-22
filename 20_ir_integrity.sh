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
  echo "[!] Запускать от root: sudo ./20_ir_integrity.sh"
  exit 1
fi

IR_DIR="${IR_DIR:-/root/ir}"

if [[ -n "${IR_RUN_DIR:-}" ]]; then
  OUT_DIR="$IR_RUN_DIR"
else
  OUT_DIR="$IR_DIR/run_$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUT_DIR"
LOG="$OUT_DIR/20-integrity.log"

{
  echo "=== SCRIPT: 20_ir_integrity.sh ==="
  date
  echo

  echo "=== DPKG VERIFY ==="
  dpkg -V 2>/dev/null | head -n 1000 || true
  echo

  echo "=== DEBSUMS ==="
  if command -v debsums >/dev/null 2>&1; then
    debsums -s 2>/dev/null | head -n 1000 || true
  else
    echo "debsums not installed"
  fi
  echo

  echo "=== APT SOURCES ==="
  grep -rE '^[^#]' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null \
    | head -n 300 || true
  echo

  echo "=== APT CONFIG SUSPICIOUS ==="
  apt-config dump 2>/dev/null \
    | grep -Ei 'proxy|pre-invoke|post-invoke|allowunauthenticated|trusted' \
    || true
  echo

  echo "=== EXECUTABLE FILES IN TMP/SHM ==="
  find /tmp /var/tmp /dev/shm -xdev -type f -executable \
    -printf '%p | user=%u group=%g size=%s mtime=%TY-%Tm-%Td %TH:%TM\n' \
    2>/dev/null | head -n 500 || true
  echo

  echo "=== SETUID/SETGID FILES ==="
  SUID_DIRS=(
    /
    /usr
    /bin
    /sbin
    /lib
    /lib64
    /opt
    /usr/local
    /etc
    /root
    /home
    /tmp
    /var/tmp
    /dev/shm
    /srv
    /var/www
  )

  EXISTING_DIRS=()
  for d in "${SUID_DIRS[@]}"; do
    [[ -d "$d" ]] && EXISTING_DIRS+=("$d")
  done

  if (( ${#EXISTING_DIRS[@]} > 0 )); then
    find "${EXISTING_DIRS[@]}" -xdev -type f \
      \( -perm -4000 -o -perm -2000 \) \
      -printf '%p | user=%u group=%g mode=%m size=%s mtime=%TY-%Tm-%Td\n' \
      2>/dev/null | sort -u | head -n 800 || true
  fi
  echo

  echo "=== FILE CAPABILITIES ==="
  CAP_DIRS=(
    /usr
    /bin
    /sbin
    /lib
    /lib64
    /opt
    /usr/local
    /etc
    /root
    /home
    /tmp
    /var/tmp
    /dev/shm
  )

  for d in "${CAP_DIRS[@]}"; do
    [[ -d "$d" ]] && getcap -r "$d" 2>/dev/null
  done | sort -u | head -n 800 || true
  echo

  echo "=== LD.SO.PRELOAD ==="
  if [[ -e /etc/ld.so.preload ]]; then
    cat /etc/ld.so.preload
  else
    echo "/etc/ld.so.preload absent"
  fi
  echo

  echo "=== LD_PRELOAD / LD_AUDIT GREP ==="
  grep -RniE 'LD_PRELOAD|LD_AUDIT' \
    /etc /usr/lib/systemd /run /usr/local/etc 2>/dev/null \
    | head -n 300 || true
  echo

  echo "=== CRON FILES ==="
  ls -lR /etc/cron* /var/spool/cron 2>/dev/null || true
  echo

  echo "=== CRON SUSPICIOUS PATTERNS ==="
  grep -RniE 'curl|wget|nc |/dev/tcp|base64|python|perl|ruby|socat' \
    /etc/crontab /etc/cron* /var/spool/cron 2>/dev/null \
    | head -n 300 || true
  echo

  echo "=== SYSTEMD SUSPICIOUS PATTERNS ==="
  grep -RniE 'ExecStart.*(tmp|dev/shm|var/tmp)|LD_PRELOAD|curl|wget|base64' \
    /etc/systemd /usr/lib/systemd /run/systemd /usr/local/lib/systemd 2>/dev/null \
    | head -n 500 || true
  echo

  echo "=== RC / PROFILE FILES ==="
  ls -l /etc/rc.local /etc/profile.d /etc/bash.bashrc \
        /root/.bashrc /root/.profile 2>/dev/null || true
  echo

  echo "=== SHELL STARTUP SUSPICIOUS PATTERNS ==="
  for f in \
    /root/.bashrc \
    /root/.profile \
    /root/.bash_profile \
    /home/*/.bashrc \
    /home/*/.profile \
    /home/*/.bash_profile \
    /home/*/.zshrc \
    /home/*/.zprofile
  do
    if [[ -f "$f" ]]; then
      grep -HinE 'curl|wget|nc |/dev/tcp|base64|LD_PRELOAD|LD_AUDIT' "$f" 2>/dev/null || true
    fi
  done | head -n 300
  echo

  echo "=== PACKAGE INSTALL/UPGRADE HISTORY ==="
  zgrep -hE ' install | upgrade | remove ' \
    /var/log/apt/history.log* /var/log/dpkg.log* 2>/dev/null \
    | tail -n 250 || true
  echo

  echo "=== JOURNAL ERRORS CURRENT BOOT ==="
  journalctl -p warning..err -b --no-pager | tail -n 300 || true
  echo

  echo "=== SSH SERVICE LOG ==="
  journalctl -u ssh -u sshd --no-pager -b 2>/dev/null | tail -n 200 || true
  echo

  echo "=== /var/log listing ==="
  ls -l /var/log | head -n 200 || true
  echo

  echo "=== JOURNAL VERIFY ==="
  journalctl --verify || true

} 2>&1 | tee "$LOG"

echo "[+] Saved: $LOG"
