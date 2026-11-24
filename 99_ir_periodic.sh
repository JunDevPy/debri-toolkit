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
PERIODIC_DIR="$IR_DIR/periodic"
SNAP_DIR="$PERIODIC_DIR/snapshots"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

if [[ $EUID -ne 0 ]]; then
  echo "[!] Запускать от root: sudo ./99_ir_periodic.sh"
  exit 1
fi

mkdir -p "$SNAP_DIR"

TS="$(date +%Y%m%d-%H%M%S)"
LOG="$PERIODIC_DIR/periodic_$TS.log"
ln -sfn "$LOG" "$PERIODIC_DIR/periodic_latest.log"

ALERTS=0
declare -a CHANGED=()

alert() {
  ALERTS=$((ALERTS + 1))
  echo "[ALERT] $*"
}

# =========================================================================
# Сборщики снимков
# =========================================================================
col_setuid() {
  find / -xdev -type f \( -perm -4000 -o -perm -2000 \) -printf '%p %m %u:%g\n' 2>/dev/null | sort
}

col_listeners() {
  ss -ltnpH 2>/dev/null | awk '{print $4, $6}' | sort -u
}

col_uid0() {
  awk -F: '$3==0 {print $1}' /etc/passwd | sort
}

col_sudoers() {
  {
    sha256sum /etc/sudoers 2>/dev/null
    find /etc/sudoers.d -maxdepth 1 -type f -print0 2>/dev/null \
      | sort -z | xargs -0 -r sha256sum 2>/dev/null
  } | sort
}

col_ak() {
  find /root /home -xdev -type f -name authorized_keys -printf '%p %u:%g %m\n' 2>/dev/null | sort
}

col_modout() {
  find / -xdev -type f \( -name '*.ko' -o -name '*.ko.*' \) \
    ! -path '/lib/modules/*' ! -path '/usr/src/*' 2>/dev/null | sort
}

col_preload() {
  if [[ -e /etc/ld.so.preload ]]; then
    cat /etc/ld.so.preload
  else
    echo ABSENT
  fi
}

col_efi() {
  if mountpoint -q /boot/efi 2>/dev/null; then
    find /boot/efi -type f \( -name '*.efi' -o -name '*.CSV' \) -print0 2>/dev/null \
      | sort -z | xargs -0 -r sha256sum 2>/dev/null | sort
  else
    echo ESP_NOT_MOUNTED
  fi
}

col_critpkg() {
  dpkg -V sudo login passwd bash coreutils util-linux systemd libc6 \
    openssh-server "linux-image-$(uname -r)" 2>/dev/null | grep -E '^..5' || true
}

col_newauto() {
  find /etc/crontab /etc/cron.d /etc/cron.hourly /etc/cron.daily \
       /etc/cron.weekly /etc/cron.monthly /etc/cron.yearly \
       /etc/systemd/system /etc/profile.d /etc/rc.local /etc/bash.bashrc \
       -xdev -type f -mtime -7 2>/dev/null | sort
}

col_delexe() {
  local p e
  for p in /proc/[0-9]*; do
    e="$(readlink "$p/exe" 2>/dev/null || true)"
    if [[ "$e" == *"(deleted)"* ]]; then
      echo "${p#/proc/} $e"
    fi
  done | sort
}

# =========================================================================
# Снимок + сравнение с предыдущим
# =========================================================================
snap_diff() {
  local name="$1"
  shift
  local cur="$SNAP_DIR/$name.list"
  local prev="$SNAP_DIR/$name.prev"

  if [[ -f "$cur" ]]; then
    cp -f "$cur" "$prev"
  fi

  { "$@"; } > "$cur.tmp" 2>/dev/null || true
  mv -f "$cur.tmp" "$cur"

  if [[ -f "$prev" ]]; then
    if ! diff -q "$prev" "$cur" >/dev/null 2>&1; then
      CHANGED+=("$name")
      echo
      echo "!!! ИЗМЕНЕНИЯ В $name (prev -> cur):"
      diff "$prev" "$cur" 2>/dev/null | head -n 100 || true
    fi
  else
    echo "[info] $name: первый снимок — сравнение появится со следующего запуска."
  fi
}

# =========================================================================
# Основной блок
# =========================================================================
{
  echo "=== PERIODIC CHECK: $(date) ==="
  echo "Host: $(hostname) | Kernel: $(uname -r)"
  echo

  echo "=== 1. СНИМКИ И СРАВНЕНИЕ ==="
  snap_diff setuid col_setuid
  snap_diff listeners col_listeners
  snap_diff uid0 col_uid0
  snap_diff sudoers col_sudoers
  snap_diff authorized_keys col_ak
  snap_diff efi_hashes col_efi
  snap_diff preload col_preload
  snap_diff modules_outside col_modout
  echo

  echo "=== 2. ALERT-ПРОВЕРКИ ==="

  if [[ "$(cat "$SNAP_DIR/preload.list" 2>/dev/null)" != "ABSENT" ]]; then
    alert "Существует /etc/ld.so.preload:"
    cat "$SNAP_DIR/preload.list" 2>/dev/null || true
  fi

  if [[ -s "$SNAP_DIR/modules_outside.list" ]]; then
    alert "Найдены файлы модулей вне /lib/modules:"
    cat "$SNAP_DIR/modules_outside.list" 2>/dev/null || true
  fi

  crit="$(col_critpkg)"
  if [[ -n "$crit" ]]; then
    alert "dpkg -V показал расхождения в критичных пакетах:"
    echo "$crit"
  fi

  if (( ${#CHANGED[@]} > 0 )); then
    for name in "${CHANGED[@]}"; do
      alert "Изменился снимок: $name (см. diff выше)"
    done
  fi

  if [[ -f "$SNAP_DIR/listeners.prev" ]]; then
    added="$(diff "$SNAP_DIR/listeners.prev" "$SNAP_DIR/listeners.list" 2>/dev/null | grep '^>' || true)"
    if echo "$added" | grep -qE '0\.0\.0\.0:|\[::\]:|\*:'; then
      alert "Появились новые слушающие TCP на внешних интерфейсах:"
      echo "$added" | grep -E '0\.0\.0\.0:|\[::\]:|\*:' || true
    fi
  fi
  echo

  echo "=== 3. INFO: новые файлы автозапуска за 7 дней ==="
  col_newauto || true
  echo

  echo "=== 4. INFO: процессы с удалённым exe ==="
  col_delexe || true
  echo

  echo "=== 5. INFO: ошибки journal за 24 часа ==="
  journalctl -p err --since "24 hours ago" --no-pager 2>/dev/null | tail -n 50 || true
  echo

  echo "=== ИТОГО ==="
  echo "Изменённые снимки: ${CHANGED[*]:-нет}"
  echo "ALERTS=$ALERTS"

} 2>&1 | tee "$LOG"

# =========================================================================
# Ротация логов
# =========================================================================
find "$PERIODIC_DIR" -maxdepth 1 -name 'periodic_*.log' -type f \
  -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true

echo
echo "[+] Лог: $LOG"

if (( ALERTS > 0 )); then
  echo "[!] Обнаружено ALERTS: $ALERTS — проверь лог."
  exit 1
fi

echo "[+] Отклонений не обнаружено."
exit 0
