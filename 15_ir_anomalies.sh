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
  echo "[!] Запускать от root: sudo ./15_ir_anomalies.sh"
  exit 1
fi

IR_DIR="${IR_DIR:-/root/ir}"

if [[ -n "${IR_RUN_DIR:-}" ]]; then
  OUT_DIR="$IR_RUN_DIR"
else
  OUT_DIR="$IR_DIR/run_$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUT_DIR"
LOG="$OUT_DIR/15-anomalies.log"

convert_ip_port() {
  local h="$1"
  local ip_hex="${h%%:*}"
  local port_hex="${h##*:}"

  if [[ ! "$ip_hex" =~ ^[0-9A-Fa-f]{8}$ ]]; then
    return 1
  fi

  if [[ ! "$port_hex" =~ ^[0-9A-Fa-f]{4}$ ]]; then
    return 1
  fi

  printf "%d.%d.%d.%d:%d\n" \
    "0x${ip_hex:6:2}" \
    "0x${ip_hex:4:2}" \
    "0x${ip_hex:2:2}" \
    "0x${ip_hex:0:2}" \
    "$((16#$port_hex))"
}

{
  echo "=== SCRIPT: 15_ir_anomalies.sh ==="
  date
  echo

  echo "=== RWX / ANONYMOUS / MEMFD MEMORY REGIONS ==="
  echo "Внимание: JIT-движки браузеров, Java, .NET, NodeJS, GPU-драйверы могут давать легитимные rwx-регионы."
  echo

  for pid in /proc/[0-9]*; do
    p="${pid#/proc/}"
    maps="$pid/maps"

    [[ -r "$maps" ]] || continue

    if awk '$2 == "rwxp" && (NF == 5 || $6 ~ /memfd|\(deleted\)/) {found=1; exit} END {exit !found}' \
         "$maps" 2>/dev/null; then

      comm=$(cat "$pid/comm" 2>/dev/null || true)
      exe=$(readlink -f "$pid/exe" 2>/dev/null || true)
      cmdline=$(tr '\0' ' ' < "$pid/cmdline" 2>/dev/null || true)

      all_rwx=$(grep -c 'rwxp' "$maps" 2>/dev/null || true)
      [[ -z "$all_rwx" ]] && all_rwx=0

      susp_rwx=$(awk '$2 == "rwxp" && (NF == 5 || $6 ~ /memfd|\(deleted\)/)' "$maps" 2>/dev/null | wc -l)

      echo "PID=$p COMM=$comm"
      echo "  EXE=$exe"
      echo "  CMD=$cmdline"
      echo "  RWX_TOTAL=$all_rwx"
      echo "  RWX_SUSPECT=$susp_rwx"

      awk '$2 == "rwxp" && (NF == 5 || $6 ~ /memfd|\(deleted\)/) {print "  MAP: " $0}' \
        "$maps" 2>/dev/null | head -n 10

      echo
    fi
  done

  echo "=== PROCESSES WITH DELETED EXE / MEMFD EXE ==="
  echo "Внимание: после обновления пакетов легитимный процесс может некоторое время иметь удалённый бинарник."
  echo

  for pid in /proc/[0-9]*; do
    p="${pid#/proc/}"
    exe=$(readlink "$pid/exe" 2>/dev/null || true)

    if [[ "$exe" == *"(deleted)"* || "$exe" == memfd:* || "$exe" == /memfd:* ]]; then
      comm=$(cat "$pid/comm" 2>/dev/null || true)
      cmdline=$(tr '\0' ' ' < "$pid/cmdline" 2>/dev/null || true)

      echo "PID=$p COMM=$comm"
      echo "  EXE=$exe"
      echo "  CMD=$cmdline"
      echo
    fi
  done

  echo "=== NETWORK NAMESPACES SNAPSHOT ==="
  echo "Если нет контейнеров/VPN/сетевых sandbox, несколько разных netns могут быть подозрительны."
  echo

  NETNS_SNAPSHOT="$OUT_DIR/netns_snapshot.txt"
  : > "$NETNS_SNAPSHOT"

  for pid in /proc/[0-9]*; do
    p="${pid#/proc/}"
    ns=$(readlink "$pid/ns/net" 2>/dev/null || true)
    comm=$(cat "$pid/comm" 2>/dev/null || true)

    if [[ -n "$ns" ]]; then
      printf '%s %s %s\n' "$ns" "$p" "$comm" >> "$NETNS_SNAPSHOT"
    fi
  done

  echo "Unique network namespace inode counts:"
  awk '{print $1}' "$NETNS_SNAPSHOT" | sort | uniq -c | sort -n
  echo

  echo "Processes by network namespace, first 300 lines:"
  head -n 300 "$NETNS_SNAPSHOT"
  echo

  echo "Named netns:"
  ip netns list 2>/dev/null || true
  ls -l /run/netns /var/run/netns 2>/dev/null || true
  echo

  echo "Container/virtualization services state:"
  for svc in docker containerd podman lxc libvirtd virtqemud; do
    state=$(systemctl is-active "$svc" 2>/dev/null || true)
    if [[ -n "$state" ]]; then
      echo "$svc=$state"
    fi
  done
  echo

  echo "=== OPEN FD REFERENCES TO OTHER /proc/PID ==="
  echo "Процессы, держащие открытые файловые дескрипторы к /proc/<чужой PID>."
  echo

  timeout -s TERM 60 bash -c '
    re="^/proc/[0-9]+(/|$)"
    for pid in /proc/[0-9]*; do
      p="${pid#/proc/}"
      comm=$(cat "$pid/comm" 2>/dev/null || true)

      for fd in "$pid"/fd/*; do
        [[ -L "$fd" ]] || continue
        target=$(readlink "$fd" 2>/dev/null || true)

        if [[ "$target" =~ $re && "$target" != "/proc/$p" && "$target" != "/proc/$p/"* ]]; then
          echo "PID=$p COMM=$comm FD=$(basename "$fd") TARGET=$target"
        fi
      done
    done
  ' 2>/dev/null | head -n 500 || true

  echo

  if [[ "${IR_ENABLE_LSOF_PROC:-0}" == "1" ]] && command -v lsof >/dev/null 2>&1; then
    echo "=== LSOF +D /proc (optional, slow) ==="
    timeout -s TERM 30 lsof +D /proc 2>/dev/null \
      | grep -v "^COMMAND" \
      | grep -Ev 'self|thread' \
      | head -n 300 || true
    echo
  else
    echo "=== LSOF +D /proc ==="
    echo "Отключено. Чтобы включить: IR_ENABLE_LSOF_PROC=1 sudo -E ./15_ir_anomalies.sh"
    echo
  fi

  echo "=== /proc/net/tcp vs ss IPv4 LOCAL ENDPOINT COMPARISON ==="
  echo "Возможны ложные срабатывания из-за быстрых изменений состояния, IPv6 и особенностей вывода ss."
  echo

  PROC_LOCAL="$OUT_DIR/proc_tcp_local.txt"
  SS_LOCAL="$OUT_DIR/ss_tcp_local.txt"

  : > "$PROC_LOCAL"
  : > "$SS_LOCAL"

  while read -r h; do
    convert_ip_port "$h" >> "$PROC_LOCAL" || true
  done < <(awk 'NR>1 {print $2}' /proc/net/tcp 2>/dev/null)

  sort -u "$PROC_LOCAL" -o "$PROC_LOCAL"

  ss -tan 2>/dev/null \
    | awk 'NR>1 && $4 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$/ {print $4}' \
    | sort -u > "$SS_LOCAL"

  echo "Local IPv4 TCP endpoints present in /proc/net/tcp but not in ss -tan:"
  comm -23 "$PROC_LOCAL" "$SS_LOCAL" | head -n 200 || true
  echo

  echo "Local IPv4 TCP endpoints present in ss -tan but not in /proc/net/tcp:"
  comm -13 "$PROC_LOCAL" "$SS_LOCAL" | head -n 200 || true
  echo

  echo "Дополнительные файлы:"
  echo "  $NETNS_SNAPSHOT"
  echo "  $PROC_LOCAL"
  echo "  $SS_LOCAL"

} 2>&1 | tee "$LOG"

echo "[+] Saved: $LOG"
