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
export IR_DIR

if [[ $EUID -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo env \
      IR_DIR="$IR_DIR" \
      SSH_AUDIT_USER="${SSH_AUDIT_USER:-}" \
      SSH_AUDIT_HOST="${SSH_AUDIT_HOST:-}" \
      SSH_AUDIT_ADDR="${SSH_AUDIT_ADDR:-}" \
      IR_ENABLE_LSOF_PROC="${IR_ENABLE_LSOF_PROC:-0}" \
      bash "$(readlink -f "${BASH_SOURCE[0]}")" "$@"
  else
    echo "[!] Нужен root. Запусти, например:"
    echo "    sudo $0 $*"
    exit 1
  fi
fi

unset IR_RUN_DIR

mkdir -p "$IR_DIR"
chmod 700 "$IR_DIR"

usage() {
  cat <<'EOF'
Использование:

  sudo ./ir_check.sh [command]

Команды проверки:

  menu                Интерактивное меню (по умолчанию)

  setup               Установить базовые пакеты
  setup-scanners      Установить базовые пакеты + сканеры

  basic               Базовая проверка
  anomalies           Продвинутые аномалии: память, deleted exe, netns, /proc/net/tcp
  ssh                 Аудит SSH, если sshd установлен
  integrity           Проверка целостности пакетов и файлов
  modules             Проверка модулей ядра
  boot                Проверка boot/UEFI/GRUB
  network             Проверка сети и firewall
  scanners            Запустить сканеры, если установлены

  all                 Все диагностические проверки без установки пакетов
  full                Установка пакетов + все диагностические проверки
  full-scanners       Установка пакетов + сканеры + все диагностические проверки

Команды аудита SSH:

  audit-ssh           Добавить runtime-правила auditctl для SSH-конфигурации
  audit-ssh-persist   Добавить runtime-правила и сохранить их в /etc/audit/rules.d

Команды очистки:

  cleanup             Показать справку очистки
  cleanup-packages    Удалить пакеты, установленные проверкой
  cleanup-audit       Удалить правила аудита SSH, добавленные проверкой
  cleanup-logs        Удалить логи и состояние из /root/ir
  cleanup-all         Удалить пакеты, правила аудита, логи и состояние

Сервисные команды:

  pack                Упаковать последний отчёт
  latest              Показать каталог последнего запуска
  help                Справка

Переменные окружения для аудита SSH:

  SSH_AUDIT_USER      Пользователь для проверки через sshd -T -C
  SSH_AUDIT_HOST      Host для проверки через sshd -T -C
  SSH_AUDIT_ADDR      Адрес клиента для проверки через sshd -T -C

Пример проверки SSH для конкретного подключения:

  sudo env SSH_AUDIT_USER=admin SSH_AUDIT_HOST=server SSH_AUDIT_ADDR=192.0.2.10 \
    ./ir_check.sh ssh

Переменные окружения для продвинутых аномалий:

  IR_ENABLE_LSOF_PROC=1   Включить медленный lsof +D /proc в anomalies

Примеры:

  sudo ./ir_check.sh full
  sudo ./ir_check.sh anomalies
  sudo ./ir_check.sh ssh
  sudo ./ir_check.sh audit-ssh
  sudo ./ir_check.sh pack

  sudo ./ir_check.sh cleanup-packages
  sudo ./ir_check.sh cleanup-audit
  sudo ./ir_check.sh cleanup-logs
  sudo ./ir_check.sh cleanup-all
EOF
}

new_run() {
  local run_dir
  run_dir="$IR_DIR/run_$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$run_dir"
  ln -sfn "$run_dir" "$IR_DIR/latest"
  export IR_RUN_DIR="$run_dir"
  echo "[*] Каталог текущего запуска: $IR_RUN_DIR"
}

ensure_run() {
  if [[ -z "${IR_RUN_DIR:-}" ]]; then
    new_run
  fi
}

run_script() {
  local script_name="$1"
  local script_path="$SCRIPT_DIR/$script_name"

  if [[ ! -f "$script_path" ]]; then
    echo "[!] Скрипт не найден: $script_path"
    return 1
  fi

  ensure_run

  echo
  echo "[*] Отдельная проверка: $script_name"
  echo "[*] Каталог запуска: $IR_RUN_DIR"
  echo

  bash "$script_path"
  local rc=$?

  echo
  if [[ $rc -eq 0 ]]; then
    echo "[*] Завершено: $script_name"
  else
    echo "[!] Завершено с ошибкой: $script_name (rc=$rc)"
  fi

  echo "[*] Каталог: $IR_RUN_DIR"

  return $rc
}

run_all() {
  new_run

  local scripts=(
    10_ir_basic.sh
    15_ir_anomalies.sh
    16_ir_ssh_audit.sh
    20_ir_integrity.sh
    30_ir_modules.sh
    40_ir_boot.sh
    50_ir_network.sh
  )

  local total=${#scripts[@]}
  local i=0
  local s
  local rc
  local start_pct
  local end_pct

  echo
  progress_line 0 0 "$total" "Начинаем проверку. Всего шагов: $total"

  for s in "${scripts[@]}"; do
    i=$((i + 1))

    start_pct=$(( (i - 1) * 100 / total ))
    end_pct=$(( i * 100 / total ))

    echo
    progress_line "$start_pct" "$i" "$total" "Запуск: $s"

    if [[ ! -f "$SCRIPT_DIR/$s" ]]; then
      progress_line "$start_pct" "$i" "$total" "ПРОПУСК: $s не найден"
      continue
    fi

    bash "$SCRIPT_DIR/$s"
    rc=$?

    if [[ $rc -eq 0 ]]; then
      progress_line "$end_pct" "$i" "$total" "Завершено: $s"
    else
      progress_line "$end_pct" "$i" "$total" "Завершено с ошибкой: $s (rc=$rc)"
    fi
  done

  echo
  progress_line 100 "$total" "$total" "Все проверки завершены. Каталог: $IR_RUN_DIR"
}

run_full() {
  if [[ ! -f "$SCRIPT_DIR/00_ir_setup.sh" ]]; then
    echo "[!] Скрипт не найден: $SCRIPT_DIR/00_ir_setup.sh"
    return 1
  fi

  bash "$SCRIPT_DIR/00_ir_setup.sh"
  run_all
}

run_full_scanners() {
  if [[ ! -f "$SCRIPT_DIR/00_ir_setup.sh" ]]; then
    echo "[!] Скрипт не найден: $SCRIPT_DIR/00_ir_setup.sh"
    return 1
  fi

  bash "$SCRIPT_DIR/00_ir_setup.sh" --with-scanners
  run_all
  run_script 60_ir_scanners.sh
}

run_audit_ssh() {
  local persist_flag="${1:-}"
  local script_path="$SCRIPT_DIR/80_ir_audit_ssh_rules.sh"
  local log_file

  if [[ ! -f "$script_path" ]]; then
    echo "[!] Скрипт не найден: $script_path"
    return 1
  fi

  ensure_run
  log_file="$IR_RUN_DIR/80-audit-ssh-rules.log"

  echo "[*] Лог правил аудита SSH: $log_file"

  if [[ "$persist_flag" == "--persist" ]]; then
    bash "$script_path" --persist 2>&1 | tee "$log_file"
  else
    bash "$script_path" 2>&1 | tee "$log_file"
  fi
}

run_cleanup() {
  local script_path="$SCRIPT_DIR/90_ir_cleanup.sh"

  if [[ ! -f "$script_path" ]]; then
    echo "[!] Скрипт не найден: $script_path"
    return 1
  fi

  bash "$script_path" "$@"
}

pack_report() {
  if [[ ! -f "$SCRIPT_DIR/70_ir_pack.sh" ]]; then
    echo "[!] Скрипт не найден: $SCRIPT_DIR/70_ir_pack.sh"
    return 1
  fi

  bash "$SCRIPT_DIR/70_ir_pack.sh"
}

show_latest() {
  readlink -f "$IR_DIR/latest" 2>/dev/null || echo "[!] latest не найден"
}

progress_line() {
  local pct="$1"
  local current="$2"
  local total="$3"
  local msg="$4"

  local line
  line=$(printf '[%3d%%] [%d/%d] %s' "$pct" "$current" "$total" "$msg")

  echo "$line"

  if [[ -n "${IR_RUN_DIR:-}" && -d "$IR_RUN_DIR" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') $line" >> "$IR_RUN_DIR/progress.log"
  fi
}

interactive_menu() {
  while true; do
    cat <<'MENU'

===============================
 IR CHECK CONTROLLER
===============================

  1) Установить базовые пакеты
  2) Установить пакеты + сканеры
  3) Все проверки без установки
  4) Установка пакетов + все проверки
  5) Установка пакетов + сканеры + все проверки

  6) Базовая проверка
  7) Продвинутые аномалии
  8) Аудит SSH
  9) Проверка целостности
 10) Проверка модулей ядра
 11) Проверка boot/UEFI/GRUB
 12) Проверка сети
 13) Проверка сканерами

 14) Добавить правила аудита SSH (runtime)
 15) Добавить правила аудита SSH (persist)

 16) Упаковать последний отчёт
 17) Показать каталог последнего отчёта

 18) Очистка: удалить пакеты
 19) Очистка: удалить правила аудита SSH
 20) Очистка: удалить логи и состояние
 21) Очистка: всё (пакеты, аудит, логи)

  0) Выход

MENU

    read -rp "Выбор: " choice || exit 0

    case "$choice" in
      1)
        bash "$SCRIPT_DIR/00_ir_setup.sh"
        ;;
      2)
        bash "$SCRIPT_DIR/00_ir_setup.sh" --with-scanners
        ;;
      3)
        run_all
        ;;
      4)
        run_full
        ;;
      5)
        run_full_scanners
        ;;
      6)
        run_script 10_ir_basic.sh
        ;;
      7)
        run_script 15_ir_anomalies.sh
        ;;
      8)
        run_script 16_ir_ssh_audit.sh
        ;;
      9)
        run_script 20_ir_integrity.sh
        ;;
      10)
        run_script 30_ir_modules.sh
        ;;
      11)
        run_script 40_ir_boot.sh
        ;;
      12)
        run_script 50_ir_network.sh
        ;;
      13)
        run_script 60_ir_scanners.sh
        ;;
      14)
        run_audit_ssh
        ;;
      15)
        run_audit_ssh --persist
        ;;
      16)
        pack_report
        ;;
      17)
        show_latest
        ;;
      18)
        run_cleanup --packages
        ;;
      19)
        run_cleanup --audit
        ;;
      20)
        run_cleanup --logs
        ;;
      21)
        run_cleanup --all
        ;;
      0)
        echo "Выход."
        exit 0
        ;;
      *)
        echo "[!] Неверный выбор."
        ;;
    esac

    echo
    read -rp "Нажми Enter, чтобы продолжить..." _ || exit 0
  done
}

CMD="${1:-menu}"

case "$CMD" in
  menu)
    interactive_menu
    ;;

  setup)
    bash "$SCRIPT_DIR/00_ir_setup.sh"
    ;;

  setup-scanners)
    bash "$SCRIPT_DIR/00_ir_setup.sh" --with-scanners
    ;;

  basic)
    run_script 10_ir_basic.sh
    ;;

  anomalies|advanced)
    run_script 15_ir_anomalies.sh
    ;;

  ssh|ssh-audit)
    run_script 16_ir_ssh_audit.sh
    ;;

  integrity)
    run_script 20_ir_integrity.sh
    ;;

  modules)
    run_script 30_ir_modules.sh
    ;;

  boot)
    run_script 40_ir_boot.sh
    ;;

  network)
    run_script 50_ir_network.sh
    ;;

  scanners)
    run_script 60_ir_scanners.sh
    ;;

  all)
    run_all
    ;;

  full)
    run_full
    ;;

  full-scanners)
    run_full_scanners
    ;;

  audit-ssh)
    run_audit_ssh
    ;;

  audit-ssh-persist)
    run_audit_ssh --persist
    ;;

  cleanup)
    run_cleanup --help
    ;;

  cleanup-packages)
    run_cleanup --packages
    ;;

  cleanup-audit)
    run_cleanup --audit
    ;;

  cleanup-logs)
    run_cleanup --logs
    ;;

  cleanup-all)
    run_cleanup --all
    ;;

  pack)
    pack_report
    ;;

  latest)
    show_latest
    ;;

  help|--help|-h)
    usage
    ;;

  *)
    usage
    exit 1
    ;;
esac
