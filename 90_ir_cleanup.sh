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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IR_DIR="${IR_DIR:-/root/ir}"

DRY_RUN=0
FORCE=0
AUTOREMOVE=0
KNOWN_FALLBACK=0

DO_PACKAGES=0
DO_AUDIT=0
DO_LOGS=0
DO_ALL=0

KNOWN_IR_PACKAGES=(
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
  rkhunter
  chkrootkit
  lynis
)

AUDIT_KEYS=(
  ssh_config
  ssh_authorizedkeyscommand
  ssh_trustedusercakeys
  ssh_authorizedprincipalsfile
)

usage() {
  cat <<'EOF'
Использование:

  sudo ./90_ir_cleanup.sh [options]

Опции:

  --packages         Удалить пакеты, установленные скриптом проверки
  --audit            Удалить правила аудита SSH, добавленные 80_ir_audit_ssh_rules.sh
  --logs             Удалить логи и состояние из /root/ir
  --all              packages + audit + logs

  --known-packages   Если нет состояния установки, использовать встроенный список пакетов
  --autoremove       После удаления пакетов выполнить apt-get autoremove --purge
  --dry-run          Только показать действия, ничего не выполнять
  --force            Не спрашивать подтверждения
  -h, --help         Справка

Примеры:

  sudo ./90_ir_cleanup.sh --dry-run --all
  sudo ./90_ir_cleanup.sh --packages
  sudo ./90_ir_cleanup.sh --audit
  sudo ./90_ir_cleanup.sh --logs
  sudo ./90_ir_cleanup.sh --all
  sudo ./90_ir_cleanup.sh --all --known-packages --autoremove --force

Важно:

  Если нужна форензика, сначала упакуй отчёт:
    sudo ./ir_check.sh pack

  Очистка уничтожает логи и установленное состояние.
EOF
}

if [[ $EUID -ne 0 ]]; then
  echo "[!] Запускать от root: sudo ./90_ir_cleanup.sh"
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --packages)
      DO_PACKAGES=1
      ;;
    --audit)
      DO_AUDIT=1
      ;;
    --logs)
      DO_LOGS=1
      ;;
    --all)
      DO_ALL=1
      ;;
    --known-packages)
      KNOWN_FALLBACK=1
      ;;
    --autoremove)
      AUTOREMOVE=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --force)
      FORCE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[!] Неизвестная опция: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ $DO_ALL -eq 1 ]]; then
  DO_PACKAGES=1
  DO_AUDIT=1
  DO_LOGS=1
fi

if [[ $DO_PACKAGES -eq 0 && $DO_AUDIT -eq 0 && $DO_LOGS -eq 0 ]]; then
  usage
  exit 1
fi

run_cmd() {
  echo "CMD: $*"
  if [[ $DRY_RUN -eq 1 ]]; then
    return 0
  fi

  "$@"
}

confirm() {
  local prompt="$1"

  if [[ $DRY_RUN -eq 1 ]]; then
    return 0
  fi

  if [[ $FORCE -eq 1 ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    echo "[!] Неинтерактивный режим. Используй --force, если действительно нужно."
    return 1
  fi

  read -rp "$prompt [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

is_pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "ok installed"
}

cleanup_packages() {
  echo
  echo "=== Очистка пакетов ==="

  local state_file="$IR_DIR/state/setup_installed_packages.txt"
  local -a candidates=()
  local -a to_remove=()
  local p

  if [[ -s "$state_file" ]]; then
    echo "[*] Использую состояние установки: $state_file"
    mapfile -t candidates < "$state_file"
  else
    echo "[!] Файл состояния не найден или пуст: $state_file"

    if [[ $KNOWN_FALLBACK -eq 1 ]]; then
      echo "[*] Использую встроенный известный список пакетов."
      candidates=("${KNOWN_IR_PACKAGES[@]}")
    else
      echo "[!] Пакеты не удалены."
      echo "    Если хочешь удалить известный список без состояния, добавь --known-packages."
      return 0
    fi
  fi

  for p in "${candidates[@]}"; do
    [[ -z "$p" ]] && continue

    if is_pkg_installed "$p"; then
      to_remove+=("$p")
    fi
  done

  if (( ${#to_remove[@]} == 0 )); then
    echo "[+] Нет установленных пакетов для удаления."
    return 0
  fi

  echo "[*] Пакеты к удалению:"
  printf '    %s\n' "${to_remove[@]}"
  echo

  if ! confirm "Удалить эти пакеты через apt-get purge?"; then
    echo "[!] Удаление пакетов отменено."
    return 0
  fi

  if run_cmd apt-get purge -y "${to_remove[@]}"; then
    if [[ $AUTOREMOVE -eq 1 ]]; then
      run_cmd apt-get autoremove --purge -y || true
    fi

    if [[ -f "$state_file" && $DRY_RUN -eq 0 ]]; then
      local tmp
      tmp=$(mktemp)

      grep -vxF -f <(printf '%s\n' "${to_remove[@]}") "$state_file" > "$tmp" || true
      cat "$tmp" > "$state_file"
      rm -f "$tmp"

      chmod 600 "$state_file"
      echo "[*] Состояние установки обновлено: $state_file"
    fi
  else
    echo "[!] apt-get purge завершился с ошибкой."
  fi
}

cleanup_audit() {
  echo
  echo "=== Очистка правил аудита SSH ==="

  local found=0
  local persistent_file="/etc/audit/rules.d/ssh-config.rules"

  if command -v auditctl >/dev/null 2>&1; then
    local line
    local key
    local -a rule_arr

    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*-w ]] || continue

      read -r -a rule_arr <<< "$line"
      (( ${#rule_arr[@]} == 0 )) && continue
      [[ "${rule_arr[0]}" == "-w" ]] || continue

      for key in "${AUDIT_KEYS[@]}"; do
        if [[ "$line" == *"$key"* ]]; then
          found=1
          rule_arr[0]="-W"

          echo "[*] Найдено правило аудита: ${rule_arr[*]}"

          if [[ $DRY_RUN -eq 1 ]]; then
            echo "DRY-RUN CMD: auditctl ${rule_arr[*]}"
          else
            if confirm "Удалить это правило аудита?"; then
              auditctl "${rule_arr[@]}" || true
            fi
          fi

          break
        fi
      done
    done < <(auditctl -l 2>/dev/null | grep -E '^[[:space:]]*-w' || true)
  else
    echo "[!] auditctl не найден. Пропускаю удаление runtime-правил."
  fi

  if [[ -f "$persistent_file" ]]; then
    found=1
    echo "[*] Найден персистентный файл правил: $persistent_file"

    if confirm "Удалить $persistent_file?"; then
      run_cmd rm -f "$persistent_file"
    fi

    if command -v augenrules >/dev/null 2>&1; then
      echo "[i] Если нужно синхронизировать правила аудита, выполни:"
      echo "    sudo augenrules --load"
    fi
  else
    echo "[+] Персистентный файл $persistent_file не найден."
  fi

  if [[ $found -eq 0 ]]; then
    echo "[+] Правила аудита, добавленные этим IR-набором, не найдены."
  fi
}

cleanup_logs() {
  echo
  echo "=== Очистка логов и состояния ==="

  if [[ ! -e "$IR_DIR" ]]; then
    echo "[+] Каталог $IR_DIR не найден."
    return 0
  fi

  if [[ "$SCRIPT_DIR" == "$IR_DIR" || "$SCRIPT_DIR" == "$IR_DIR"/* ]]; then
    echo "[!] ВНИМАНИЕ: каталог скриптов находится внутри или совпадает с $IR_DIR."
    echo "    Удаление может удалить и сами скрипты."
  fi

  echo "[*] Будет удалён каталог: $IR_DIR"

  if confirm "Удалить логи, состояние и каталог $IR_DIR полностью?"; then
    run_cmd rm -rf "$IR_DIR"
  else
    echo "[!] Удаление логов отменено."
  fi
}

echo "[*] IR cleanup"
echo "[*] IR_DIR: $IR_DIR"

if [[ $DRY_RUN -eq 1 ]]; then
  echo "[*] Режим: DRY-RUN"
fi

if [[ $FORCE -eq 1 ]]; then
  echo "[*] Режим: FORCE"
fi

# Порядок важен:
# 1. Сначала пакеты, пока жив файл состояния.
# 2. Потом правила аудита.
# 3. В конце логи и состояние.

if [[ $DO_PACKAGES -eq 1 ]]; then
  cleanup_packages
fi

if [[ $DO_AUDIT -eq 1 ]]; then
  cleanup_audit
fi

if [[ $DO_LOGS -eq 1 ]]; then
  cleanup_logs
fi

echo
echo "[+] Очистка завершена."
