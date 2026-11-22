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
  echo "[!] Запускать от root: sudo ./80_ir_audit_ssh_rules.sh"
  exit 1
fi

PERSIST=0
if [[ "${1:-}" == "--persist" ]]; then
  PERSIST=1
fi

if ! command -v auditctl >/dev/null 2>&1; then
  echo "[!] auditctl не найден."
  echo "Установи: sudo apt install auditd"
  exit 1
fi

RULE_FILE="/etc/audit/rules.d/ssh-config.rules"

if [[ $PERSIST -eq 1 ]]; then
  mkdir -p /etc/audit/rules.d
  : > "$RULE_FILE"
  echo "[*] Персистентные правила будут записаны в $RULE_FILE"
fi

add_watch() {
  local path="$1"
  local key="$2"

  if [[ -e "$path" ]]; then
    echo "[*] Добавляю watch: $path key=$key"
    auditctl -w "$path" -p wa -k "$key" || true

    if [[ $PERSIST -eq 1 ]]; then
      echo "-w $path -p wa -k $key" >> "$RULE_FILE"
    fi
  else
    echo "[!] Путь не найден, пропускаю: $path"
  fi
}

echo "=== Добавление аудита SSH-конфигурации ==="

add_watch "/etc/ssh/sshd_config" "ssh_config"
add_watch "/etc/ssh/sshd_config.d" "ssh_config"

SSHD_BIN=$(command -v sshd 2>/dev/null || true)

if [[ -z "$SSHD_BIN" && -x /usr/sbin/sshd ]]; then
  SSHD_BIN="/usr/sbin/sshd"
fi

if [[ -n "$SSHD_BIN" ]]; then
  SSHD_T=$("$SSHD_BIN" -T 2>/dev/null || true)

  if [[ -n "$SSHD_T" ]]; then
    akc_line=$(sed -n 's/^authorizedkeyscommand //p' <<< "$SSHD_T" | head -n 1)
    akc_bin=$(awk '{print $1}' <<< "$akc_line")

    if [[ -n "$akc_bin" && "$akc_bin" != "none" ]]; then
      add_watch "$akc_bin" "ssh_authorizedkeyscommand"
    fi

    ca=$(sed -n 's/^trustedusercakeys //p' <<< "$SSHD_T" | head -n 1)
    if [[ -n "$ca" && "$ca" != "none" ]]; then
      add_watch "$ca" "ssh_trustedusercakeys"
    fi

    apf=$(sed -n 's/^authorizedprincipalsfile //p' <<< "$SSHD_T" | head -n 1)
    if [[ -n "$apf" && "$apf" != "none" ]]; then
      add_watch "$apf" "ssh_authorizedprincipalsfile"
    fi
  else
    echo "[!] Не удалось получить вывод sshd -T. Дополнительные пути не добавлены."
  fi
else
  echo "[!] sshd не найден. Добавляю только watch на /etc/ssh, если каталог существует."
fi

echo
echo "=== Текущие правила auditctl ==="
auditctl -l || true

if [[ $PERSIST -eq 1 ]]; then
  echo
  echo "[+] Файл персистентных правил: $RULE_FILE"
  echo "Применить можно командой:"
  echo "  sudo augenrules --load"
fi

echo
echo "=== Последние события аудита по ключам SSH ==="

if command -v ausearch >/dev/null 2>&1; then
  ausearch -k ssh_config --start today -i || true
  echo
  ausearch -k ssh_authorizedkeyscommand --start today -i || true
  echo
  ausearch -k ssh_trustedusercakeys --start today -i || true
  echo
  ausearch -k ssh_authorizedprincipalsfile --start today -i || true
else
  echo "[!] ausearch не найден."
fi
