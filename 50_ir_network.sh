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
  echo "[!] Запускать от root: sudo ./50_ir_network.sh"
  exit 1
fi

IR_DIR="${IR_DIR:-/root/ir}"

if [[ -n "${IR_RUN_DIR:-}" ]]; then
  OUT_DIR="$IR_RUN_DIR"
else
  OUT_DIR="$IR_DIR/run_$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUT_DIR"
LOG="$OUT_DIR/50-network.log"

{
  echo "=== SCRIPT: 50_ir_network.sh ==="
  date
  echo

  echo "=== INTERFACES ==="
  ip -d addr || true
  ip -d link || true
  echo

  echo "=== ROUTES ==="
  ip route || true
  ip route show table all | head -n 200 || true
  ip rule || true
  echo

  echo "=== ARP/NEIGHBOR ==="
  ip neigh || true
  echo

  echo "=== LISTEN SOCKETS ==="
  ss -tulpn || true
  echo

  echo "=== ESTABLISHED TCP ==="
  ss -tnp | head -n 300 || true
  echo

  echo "=== LSOF NETWORK ==="
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -i | head -n 300 || true
  else
    echo "lsof unavailable"
  fi
  echo

  echo "=== IPTABLES ==="
  if command -v iptables >/dev/null 2>&1; then
    iptables -S || true
    iptables -t nat -S || true
    iptables -t mangle -S || true
  else
    echo "iptables unavailable"
  fi
  echo

  echo "=== IP6TABLES ==="
  if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -S || true
    ip6tables -t nat -S || true
    ip6tables -t mangle -S || true
  else
    echo "ip6tables unavailable"
  fi
  echo

  echo "=== NFTABLES ==="
  if command -v nft >/dev/null 2>&1; then
    nft list ruleset || true
  else
    echo "nft unavailable"
  fi
  echo

  echo "=== DNS / RESOLVER ==="
  cat /etc/resolv.conf 2>/dev/null || true

  if command -v resolvectl >/dev/null 2>&1; then
    resolvectl status || true
  elif command -v systemd-resolve >/dev/null 2>&1; then
    systemd-resolve --status || true
  fi
  echo

  echo "=== HOSTS ==="
  grep -v '^#' /etc/hosts 2>/dev/null || true
  echo

  echo "=== NSSWITCH RELEVANT ==="
  grep -E '^(hosts|passwd|group|shadow|sudoers):' /etc/nsswitch.conf 2>/dev/null || true
  echo

  echo "=== PROXY SETTINGS IN COMMON FILES ==="
  for f in \
    /etc/environment \
    /etc/profile.d/* \
    /root/.bashrc \
    /root/.profile \
    /home/*/.bashrc \
    /home/*/.profile
  do
    if [[ -e "$f" ]]; then
      grep -HinE 'http_proxy|https_proxy|no_proxy' "$f" 2>/dev/null || true
    fi
  done | head -n 300
  echo

  echo "=== APT PROXY/HOOKS ==="
  apt-config dump 2>/dev/null \
    | grep -Ei 'proxy|pre-invoke|post-invoke|allowunauthenticated|trusted' \
    || true
  echo

  echo "=== NETWORK CONFIG FILES ==="
  ls -l \
    /etc/network \
    /etc/netplan \
    /etc/systemd/network \
    /etc/NetworkManager/conf.d \
    /etc/NetworkManager/system-connections \
    2>/dev/null || true
  echo

  echo "=== NETWORK MANAGER CONNECTIONS ==="
  if command -v nmcli >/dev/null 2>&1; then
    nmcli connection show || true
    nmcli device status || true
  else
    echo "nmcli unavailable"
  fi
  echo

  echo "=== /etc/network/interfaces ==="
  grep -rE '^[^#]' /etc/network/interfaces /etc/network/interfaces.d 2>/dev/null \
    | head -n 200 || true
  echo

  echo "=== DHCP HOOKS ==="
  ls -l \
    /etc/dhcp/dhclient-enter-hooks.d \
    /etc/dhcp/dhclient-exit-hooks.d \
    /etc/dhcp/dhclient.conf \
    2>/dev/null || true

} 2>&1 | tee "$LOG"

echo "[+] Saved: $LOG"
