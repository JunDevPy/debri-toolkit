# DEBRI-Toolkit — набор скриптов для первичной проверки хоста на компрометацию

> Copyright (c) 2026 Глазов Андрей / JunDevPy · License: MIT + Commons Clause
> Original source: <https://github.com/JunDevPy/debri-toolkit>

**DEBRI-Toolkit** — набор `bash`-скриптов для первичной диагностики возможного взлома хоста на базе **Debian / Ubuntu** и совместимых систем.

Расшифровка названия:

```text
DEBRI — Debian/Ubuntu Bash Response & Inspection
```

Скрипты помогают собрать и зафиксировать:

- процессы, сеть, пользователей, сервисы;
- целостность установленных пакетов;
- подозрительные файлы, `setuid`/`setgid`, capabilities;
- модули ядра;
- состояние загрузчика, UEFI, Secure Boot, GRUB;
- сетевые настройки, маршруты, firewall, DNS, прокси;
- расширенные аномалии процессов, памяти и сетевых namespace;
- конфигурацию SSH, включая `AuthorizedKeysCommand`, `TrustedUserCAKeys`, `Match`-блоки;
- правила аудита изменений SSH-конфигурации;
- краткую сводку подозрительных находок;
- периодические снимки состояния системы для мониторинга изменений;
- итоговый архив с логами для передачи аналитику.

> [!WARNING]
> Скрипты предназначены для проверки уже установленной системы.
>
> Если есть серьёзное подозрение на руткит, компрометацию ядра, загрузчика или UEFI, более надёжно выполнять проверку с заведомо чистого **Live USB**, монтируя диск только для чтения.
>
> Данный набор хорошо подходит для первичного триажа и сбора артефактов, но не даёт 100% гарантии при активном рутките.

---

## Состав репозитория

| Файл | Назначение |
|---|---|
| `00_ir_setup.sh` | Установка диагностических пакетов (включая `bsd-mailx`) и подготовка каталога логов. Запоминает установленные пакеты в состоянии. |
| `10_ir_basic.sh` | Базовый триаж: процессы, сеть, пользователи, сервисы, модули ядра, USB/PCI, `dmesg`. |
| `15_ir_anomalies.sh` | Расширенные аномалии: `rwxp`-регионы памяти, удалённые `exe`, `memfd`, сетевые namespace, сравнение `/proc/net/tcp` и `ss`. |
| `16_ir_ssh_audit.sh` | Аудит SSH: эффективный конфиг `sshd -T`, `Match`-контексты, `AuthorizedKeysCommand`, `TrustedUserCAKeys`. Если SSH не установлен, проверка пропускается. |
| `20_ir_integrity.sh` | Проверка целостности пакетов, подозрительных файлов, `setuid`/`setgid`, capabilities, cron, systemd, shell startup, логов. |
| `30_ir_modules.sh` | Детальная проверка модулей ядра: владелец пакета, подпись, путь, подозрительные файлы модулей, автозагрузка. |
| `40_ir_boot.sh` | Проверка boot/UEFI/GRUB: EFI-записи, Secure Boot, MOK, файлы в `/boot`, EFI System Partition, firmware-диагностика. |
| `50_ir_network.sh` | Проверка сети: интерфейсы, маршруты, сокеты, firewall, DNS, hosts, прокси, конфиги сети. |
| `60_ir_scanners.sh` | Опциональные сканеры: `rkhunter`, `chkrootkit`, `lynis`, если они были установлены. |
| `70_ir_pack.sh` | Упаковка последнего каталога проверок в `tar.gz` и создание `.sha256`. |
| `75_ir_export.sh` | Экспорт последнего отчёта в домашнюю папку пользователя с исправлением владельца и прав. |
| `80_ir_audit_ssh_rules.sh` | Добавление правил `auditctl` для отслеживания изменений SSH-конфигурации. Опционально сохраняет правила персистентно. |
| `90_ir_cleanup.sh` | Очистка: удаление установленных диагностических пакетов, правил аудита, логов и состояния. |
| `95_ir_summarize.sh` | Формирует краткую сводку подозрительных строк из логов последнего запуска: `99-summary.txt` (включая блоки модулей ядра и UEFI). |
| `99_ir_periodic.sh` | Периодическая быстрая проверка: снимки состояния (setuid, listeners, UID 0, sudoers, authorized_keys, EFI, preload, модули вне `/lib/modules`) и сравнение с предыдущим снимком. Поднимает ALERTS при изменениях. |
| `ir_check.sh` | Контроллер: меню, команды, запуск проверок, прогресс, сводка, упаковка, экспорт, периодика и очистка. |

---

## Требования

- **Debian 12/13**, **Ubuntu** или совместимая система с `apt` и `dpkg`;
- права `root`;
- `bash`;
- для установки пакетов нужен доступ к репозиториям;
- для полной проверки SSH должен быть установлен `openssh-server`; если SSH не установлен, проверка SSH будет пропущена.

По умолчанию логи пишутся в:

```text
/root/ir
```

Каталог можно изменить через переменную окружения `IR_DIR`.

---

## Быстрый старт

### Вариант 1. Клонировать репозиторий

```bash
git clone https://github.com/JunDevPy/debri-toolkit.git
cd debri-toolkit
chmod +x *.sh
sudo ./ir_check.sh
```

### Вариант 2. Скопировать скрипты вручную

```bash
mkdir -p ~/debri-toolkit
cp /path/to/scripts/*.sh ~/debri-toolkit/
cd ~/debri-toolkit
chmod +x *.sh
```

Затем:

```bash
sudo ./ir_check.sh
```

или сразу:

```bash
sudo ./ir_check.sh full
```

> [!TIP]
> Не рекомендуется хранить сами скрипты внутри `/root/ir`, потому что этот каталог может быть удалён командой очистки логов.

---

## Рекомендуемый порядок использования

### 1. Установить инструменты и выполнить все проверки

```bash
sudo ./ir_check.sh full
```

### 2. Сформировать краткую сводку результатов

```bash
sudo ./ir_check.sh summarize
```

Будет создан файл:

```text
/root/ir/latest/99-summary.txt
```

### 3. Упаковать отчёт

```bash
sudo ./ir_check.sh pack
```

### 4. Скопировать отчёт в домашнюю папку и поправить права

```bash
sudo ./ir_check.sh export
```

Результат:

```text
~/ir_report_YYYYmmdd-HHMMSS.tar.gz
~/ir_report_YYYYmmdd-HHMMSS.tar.gz.sha256
```

### 5. Включить периодический мониторинг (опционально)

```bash
sudo ./ir_check.sh periodic
```

или автоматически через systemd timer (см. `README_FULL.md`, раздел «Периодические проверки»).

---

## Основные команды

| Команда | Назначение |
|---|---|
| `sudo ./ir_check.sh` | Интерактивное меню. |
| `sudo ./ir_check.sh full` | Установка пакетов + все проверки. |
| `sudo ./ir_check.sh full-scanners` | Установка пакетов + сканеры + все проверки. |
| `sudo ./ir_check.sh all` | Все проверки без установки пакетов. |
| `sudo ./ir_check.sh basic` | Базовая проверка. |
| `sudo ./ir_check.sh anomalies` | Расширенные аномалии процессов, памяти и сети. |
| `sudo ./ir_check.sh ssh` | Аудит SSH. |
| `sudo ./ir_check.sh integrity` | Проверка целостности. |
| `sudo ./ir_check.sh modules` | Проверка модулей ядра. |
| `sudo ./ir_check.sh boot` | Проверка boot/UEFI/GRUB. |
| `sudo ./ir_check.sh network` | Проверка сети. |
| `sudo ./ir_check.sh scanners` | Запуск сканеров. |
| `sudo ./ir_check.sh summarize` | Создать краткую сводку `99-summary.txt`. |
| `sudo ./ir_check.sh pack` | Упаковать последний отчёт. |
| `sudo ./ir_check.sh export` | Скопировать отчёт в домашнюю папку и исправить права. |
| `sudo ./ir_check.sh periodic` | Быстрая периодическая проверка со сравнением снимков. |
| `sudo ./ir_check.sh audit-ssh` | Добавить runtime-правила аудита для SSH. |
| `sudo ./ir_check.sh audit-ssh-persist` | Добавить правила аудита для SSH и сохранить их. |
| `sudo ./ir_check.sh cleanup-packages` | Удалить установленные диагностические пакеты. |
| `sudo ./ir_check.sh cleanup-audit` | Удалить правила аудита SSH. |
| `sudo ./ir_check.sh cleanup-logs` | Удалить логи и состояние из `/root/ir`. |
| `sudo ./ir_check.sh cleanup-all` | Удалить пакеты, правила аудита, логи и состояние. |
| `sudo ./ir_check.sh latest` | Показать каталог последнего запуска. |

---

## Логи

После проверки логи будут находиться в:

```text
/root/ir/latest
```

Пример содержимого:

```text
/root/ir/latest
├── 10-basic.log
├── 15-anomalies.log
├── 16-ssh-audit.log
├── 20-integrity.log
├── 30-modules.log
├── 40-boot.log
├── 50-network.log
├── 60-scanners.log
├── 80-audit-ssh-rules.log
├── 99-summary.txt
├── progress.log
├── netns_snapshot.txt
├── proc_tcp_local.txt
├── ss_tcp_local.txt
├── sshd-T.txt
└── ...
```

Периодические проверки хранятся отдельно:

```text
/root/ir/periodic
├── periodic_YYYYmmdd-HHMMSS.log
├── periodic_latest.log -> periodic_YYYYmmdd-HHMMSS.log
└── snapshots/
    ├── setuid.list / setuid.prev
    ├── listeners.list / listeners.prev
    ├── uid0.list / uid0.prev
    ├── sudoers.list / sudoers.prev
    ├── authorized_keys.list / .prev
    ├── efi_hashes.list / .prev
    ├── preload.list / .prev
    └── modules_outside.list / .prev
```

Анализ лучше начинать с:

```text
99-summary.txt
```

и:

```text
progress.log
```

---

## Прогресс выполнения

Во время запуска через контроллер выводится статус в процентах и дублируется в:

```text
/root/ir/latest/progress.log
```

Пример:

```text
[  0%] [0/7] Начинаем проверку. Всего шагов: 7
[ 14%] [1/7] Запуск: 10_ir_basic.sh
[ 14%] [1/7] Завершено: 10_ir_basic.sh
[ 28%] [2/7] Запуск: 15_ir_anomalies.sh
...
[100%] [7/7] Все проверки завершены
```

Прогресс считается по количеству проверочных скриптов, а не по каждой внутренней команде.

Смотреть в реальном времени:

```bash
tail -f /root/ir/latest/progress.log
```

---

## Очистка после проверки

> [!CAUTION]
> Очистка уничтожает собранные логи и состояние.
>
> Если есть подозрение на взлом, сначала упакуйте отчёт:
>
> ```bash
> sudo ./ir_check.sh pack
> sudo ./ir_check.sh export
> ```

Посмотреть, что будет сделано:

```bash
sudo ./90_ir_cleanup.sh --dry-run --all
```

Удалить пакеты / аудит / логи / всё:

```bash
sudo ./ir_check.sh cleanup-packages
sudo ./ir_check.sh cleanup-audit
sudo ./ir_check.sh cleanup-logs
sudo ./ir_check.sh cleanup-all
```

---

## Что считать подозрительным

В первую очередь обращайте внимание на:

- неизвестные модули ядра и модули без владельца пакета;
- процессы с удалённым `exe`;
- исполняемые файлы в `/tmp`, `/var/tmp`, `/dev/shm`;
- чужие `authorized_keys`;
- неизвестных пользователей с UID 0;
- странные `setuid`/`setgid` файлы;
- `LD_PRELOAD` и `/etc/ld.so.preload`;
- неизвестные сетевые соединения и новые внешние TCP-листенеры;
- изменения `sshd_config`, `AuthorizedKeysCommand`, `TrustedUserCAKeys`;
- неизвестные `.efi`-файлы и записи в `efibootmgr`;
- строки `[ALERT]` в логах периодических проверок;
- подозрительные строки в `99-summary.txt`.

---

## Подробная документация

Полное техническое описание, разбор логов, сценарии использования, периодический мониторинг, ограничения и действия при инциденте:

[Полное техническое описание](README_FULL.md)

---

## Важное предупреждение

Если найдены серьёзные красные флаги:

1. Сохраните отчёт:

   ```bash
   sudo ./ir_check.sh pack
   sudo ./ir_check.sh export
   ```

2. Скопируйте архив на внешний носитель или доверенный хост.
3. Отключите машину от сети.
4. Не вводите на ней важные пароли, ключи и коды 2FA.
5. Перейдите к офлайн-проверке с Live USB.
6. При подтверждении компрометации переустановите систему, обновите UEFI/BIOS и замените ключи/пароли.

---

## Лицензия

MIT + Commons Clause. Продажа и перепродажа скрипта или его модификаций запрещена всем, кроме правообладателя. При использовании в любых системах обязательно явное указание автора.
