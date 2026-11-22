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
LATEST="${1:-$(readlink -f "$IR_DIR/latest" 2>/dev/null || true)}"

if [[ -z "$LATEST" || ! -d "$LATEST" ]]; then
  echo "[!] Не найден каталог последнего запуска."
  echo "Ожидалось: $IR_DIR/latest"
  echo
  echo "Сначала запусти проверки, например:"
  echo "  sudo ./ir_check.sh all"
  exit 1
fi

SUMMARY="$LATEST/99-summary.txt"

grep_section() {
  local file="$1"
  local pattern="$2"
  local title="$3"
  local max_lines="${4:-150}"

  echo
  echo "==================================================="
  echo "=== $title ==="
  echo "==================================================="

  if [[ -f "$LATEST/$file" ]]; then
    echo "Source: $file"
    echo
    grep -EinH "$pattern" "$LATEST/$file" | head -n "$max_lines" || true
  else
    echo "Файл не найден: $file"
  fi
}

{
  echo "==================================================="
  echo "=== IR SUMMARY ==="
  echo "==================================================="
  date
  echo
  echo "Latest run dir: $LATEST"
  echo

  echo "==================================================="
  echo "=== FILES IN RUN DIR ==="
  echo "==================================================="
  ls -l "$LATEST"

  grep_section \
    "10-basic.log" \
    'UID=0|authorized_keys|LISTEN|ESTAB|deleted|LD_PRELOAD|cap_sys_module|docker|sudo|wheel|sshd|/tmp/|/dev/shm/' \
    "BASIC: пользователи, сеть, ключи, подозрительные строки" \
    200

  grep_section \
    "15-anomalies.log" \
    'RWX_SUSPECT|DELETED|memfd|MEMFD|network namespace|netns|/proc/net/tcp|PID=|EXE=|CMD=' \
    "ANOMALIES: память, удалённые процессы, netns, /proc/net/tcp" \
    300

  grep_section \
    "16-ssh-audit.log" \
    'AuthorizedKeysCommand|AuthorizedKeysCommandUser|TrustedUserCAKeys|AuthorizedPrincipalsFile|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|sshd -t failed|sshd -T failed|not found|SSH server likely not installed' \
    "SSH: эффективный конфиг и подозрительные механизмы доступа" \
    300

  grep_section \
    "20-integrity.log" \
    'dpkg|debsums|setuid|setgid|cap_|LD_PRELOAD|LD_AUDIT|/etc/ld.so.preload|/tmp/|/var/tmp/|/dev/shm/|cron|systemd|ExecStart|base64|/dev/tcp|curl|wget|nc ' \
    "INTEGRITY: пакеты, setuid, capabilities, cron, systemd, preload" \
    400

  grep_section \
    "30-modules.log" \
    'file=|signer=|pkg=|module verification|lockdown|signature|taint|dkms|outside|/tmp/|/dev/shm/|/home/' \
    "MODULES: модули ядра, подписи, владельцы пакетов" \
    300

  grep_section \
    "40-boot.log" \
    'EFI|UEFI|Secure Boot|MOK|efibootmgr|cmdline|GRUB|grub|/boot|/boot/efi|fwupd|BIOS' \
    "BOOT: UEFI, Secure Boot, GRUB, /boot" \
    300

  grep_section \
    "50-network.log" \
    'LISTEN|ESTAB|iptables|ip6tables|nft|proxy|dns|hosts|route|resolv|dhcp|NetworkManager|/etc/network|/etc/systemd/network' \
    "NETWORK: сокеты, маршруты, firewall, DNS, прокси" \
    400

  grep_section \
    "60-scanners.log" \
    'Warning|WARNING|ERROR|error|possible|rootkit|suspicious|infected| compromised' \
    "SCANNERS: предупреждения сканеров" \
    300

  grep_section \
    "80-audit-ssh-rules.log" \
    'audit|watch|ssh_config|AuthorizedKeysCommand|TrustedUserCAKeys|AuthorizedPrincipalsFile|error|fail' \
    "AUDIT: правила аудита SSH" \
    200

  echo
  echo "==================================================="
  echo "=== END OF SUMMARY ==="
  echo "==================================================="

} | tee "$SUMMARY"

echo
echo "[+] Сводка сохранена: $SUMMARY"
