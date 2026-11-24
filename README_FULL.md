# DEBRI-Toolkit — полная техническая документация

> Copyright (c) 2026 Глазов Андрей / JunDevPy · License: MIT + Commons Clause
> Original source: <https://github.com/JunDevPy/debri-toolkit>

Данный документ описывает работу набора скриптов **DEBRI-Toolkit**, предназначенного для первичной проверки хоста на признаки компрометации.

Основной короткий файл: [`README.md`](README.md).

Расшифровка названия:

```text
DEBRI — Debian/Ubuntu Bash Response & Inspection
```

---

## 1. Назначение проекта

DEBRI-Toolkit предназначен для:

- первичного триажа возможной компрометации;
- сбора диагностических артефактов;
- поиска очевидных красных флагов;
- проверки целостности пакетов;
- анализа модулей ядра, автозапуска, сети, пользователей, SSH, UEFI/GRUB;
- поиска расширенных аномалий процессов и памяти;
- формирования краткой сводки подозрительных находок;
- периодического мониторинга изменений состояния системы;
- упаковки результатов для передачи аналитику;
- последующей очистки установленных диагностических пакетов и логов.

Набор **не является**:

- полноценным антивирусом;
- гарантированным средством обнаружения руткитов;
- заменой офлайн-форензики;
- заменой анализа оперативной памяти;
- заменой EDR/XDR;
- средством автоматического лечения системы.

---

## 2. Важное предупреждение

> [!WARNING]
> Проверка изнутри работающей системы не даёт 100% гарантии, если ядро, загрузчик или привилегированные процессы уже скомпрометированы.
>
> Руткит может скрывать процессы, файлы, модули ядра, сетевые соединения, записи в логах и изменения конфигурации.

Если есть серьёзные подозрения:

1. Сначала сохраните собранные логи.
2. Не вводите важные пароли и ключи на подозрительной системе.
3. По возможности выполните проверку с чистого Live USB.
4. При подтверждении компрометации переустановите систему и замените все секреты.

---

## 3. Состав проекта

| Файл | Назначение |
|---|---|
| `00_ir_setup.sh` | Установка диагностических пакетов, создание каталога логов, сохранение состояния установленных пакетов. |
| `10_ir_basic.sh` | Базовый триаж: процессы, сеть, пользователи, сервисы, модули ядра, USB/PCI, `dmesg`. |
| `15_ir_anomalies.sh` | Расширенные аномалии процессов, памяти, сетевых namespace и `/proc/net/tcp`. |
| `16_ir_ssh_audit.sh` | Аудит SSH: эффективный конфиг `sshd`, `Match`-контексты, ключи, команды, сертификаты. |
| `20_ir_integrity.sh` | Проверка целостности пакетов, подозрительных файлов, `setuid`, capabilities, cron, systemd, shell startup, логов. |
| `30_ir_modules.sh` | Проверка модулей ядра, подписей, владельцев пакетов, автозагрузки модулей. |
| `40_ir_boot.sh` | Проверка UEFI/BIOS, Secure Boot, GRUB, EFI-файлов, firmware security. |
| `50_ir_network.sh` | Проверка сетевых интерфейсов, маршрутов, сокетов, firewall, DNS, прокси, сетевых конфигов. |
| `60_ir_scanners.sh` | Запуск `rkhunter`, `chkrootkit`, `lynis`, если они установлены. |
| `70_ir_pack.sh` | Упаковка последнего каталога проверок в архив и создание `.sha256`. |
| `75_ir_export.sh` | Экспорт последнего отчёта в домашнюю папку пользователя с исправлением владельца и прав. |
| `80_ir_audit_ssh_rules.sh` | Добавление правил аудита для отслеживания изменений SSH-конфигурации. |
| `90_ir_cleanup.sh` | Очистка пакетов, правил аудита, логов и состояния. |
| `95_ir_summarize.sh` | Создание краткой сводки подозрительных строк из логов последнего запуска, включая блоки модулей ядра и UEFI. |
| `99_ir_periodic.sh` | Периодическая быстрая проверка со сравнением снимков состояния и ALERTS. |
| `ir_check.sh` | Контроллер: меню, команды, управление прогонами, прогрессом и логами. |

---

## 4. Требования

### Поддерживаемые системы

- Debian 12;
- Debian 13;
- Ubuntu LTS;
- другие производные, где есть `apt`, `dpkg`, `systemd`, `procfs`, `sysfs`.

На других дистрибутивах скрипты могут работать частично или требовать адаптации.

### Обязательные требования

- `bash`;
- права `root`;
- стандартные утилиты: `ps`, `ss`, `find`, `grep`, `awk`, `sed`, `stat`, `readlink`, `tar`, `diff`, `sha256sum`.

### Пакеты, устанавливаемые `00_ir_setup.sh`

```text
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
ca-certificates
bsd-mailx
```

> [!NOTE]
> `bsd-mailx` включён в базовый список, потому что `chkrootkit-daily` вызывает команду `mail`. Без него `chkrootkit.service` падает с `status=127`.

Опциональные сканеры (`--with-scanners`):

```text
rkhunter
chkrootkit
lynis
```

---

## 5. Размещение и установка

### Вариант 1. Клонирование репозитория

```bash
git clone https://github.com/JunDevPy/debri-toolkit.git
cd debri-toolkit
chmod +x *.sh
sudo ./ir_check.sh
```

### Вариант 2. Ручное копирование

```bash
mkdir -p ~/debri-toolkit
cp /path/to/scripts/*.sh ~/debri-toolkit/
cd ~/debri-toolkit
chmod +x *.sh
```

Альтернативный вариант через `install`:

```bash
mkdir -p ~/debri-toolkit
install -m 0755 /path/to/scripts/*.sh ~/debri-toolkit/
cd ~/debri-toolkit
```

> [!TIP]
> Не размещайте скрипты внутри `/root/ir`, если планируете использовать очистку логов.
> Очистка логов может удалить весь каталог `/root/ir`.

---

## 6. Каталог логов

По умолчанию используется:

```text
/root/ir
```

Структура:

```text
/root/ir
├── latest -> /root/ir/run_YYYYmmdd-HHMMSS
├── run_YYYYmmdd-HHMMSS
│   ├── 10-basic.log
│   ├── 15-anomalies.log
│   ├── 16-ssh-audit.log
│   ├── 20-integrity.log
│   ├── 30-modules.log
│   ├── 40-boot.log
│   ├── 50-network.log
│   ├── 60-scanners.log
│   ├── 80-audit-ssh-rules.log
│   ├── 99-summary.txt
│   ├── progress.log
│   ├── netns_snapshot.txt
│   ├── proc_tcp_local.txt
│   ├── ss_tcp_local.txt
│   ├── sshd-T.txt
│   ├── sshd-T.err
│   └── ...
├── periodic
│   ├── periodic_YYYYmmdd-HHMMSS.log
│   ├── periodic_latest.log -> periodic_YYYYmmdd-HHMMSS.log
│   └── snapshots/
│       ├── setuid.list / setuid.prev
│       ├── listeners.list / listeners.prev
│       ├── uid0.list / uid0.prev
│       ├── sudoers.list / sudoers.prev
│       ├── authorized_keys.list / .prev
│       ├── efi_hashes.list / .prev
│       ├── preload.list / .prev
│       └── modules_outside.list / .prev
├── state
│   └── setup_installed_packages.txt
├── ir_report_YYYYmmdd-HHMMSS.tar.gz
└── ir_report_YYYYmmdd-HHMMSS.tar.gz.sha256
```

`/root/ir/latest` — символическая ссылка на последний полный прогон.

---

## 7. Прогресс выполнения

Во время выполнения проверок через `ir_check.sh` выводится статус в процентах:

```text
[  0%] [0/7] Начинаем проверку. Всего шагов: 7
[ 14%] [1/7] Запуск: 10_ir_basic.sh
[ 14%] [1/7] Завершено: 10_ir_basic.sh
[ 28%] [2/7] Запуск: 15_ir_anomalies.sh
[ 28%] [2/7] Завершено: 15_ir_anomalies.sh
...
[100%] [7/7] Все проверки завершены
```

Особенности:

- прогресс считается по количеству проверочных скриптов;
- внутренние команды отдельного скрипта не имеют отдельного процента;
- статус дублируется в `/root/ir/latest/progress.log`.

Просмотр прогресса из другого терминала:

```bash
tail -f /root/ir/latest/progress.log
```

---

## 8. Переменные окружения

| Переменная | Назначение | По умолчанию |
|---|---|---|
| `IR_DIR` | Каталог для логов и состояния. | `/root/ir` |
| `SSH_AUDIT_USER` | Пользователь для проверки `sshd -T -C`. | `root` |
| `SSH_AUDIT_HOST` | Хост для проверки `sshd -T -C`. | `localhost` |
| `SSH_AUDIT_ADDR` | Адрес клиента для проверки `sshd -T -C`. | `127.0.0.1` |
| `IR_ENABLE_LSOF_PROC` | Включает медленный `lsof +D /proc` в `15_ir_anomalies.sh`. | `0` |
| `RETENTION_DAYS` | Сколько дней хранить логи периодических проверок. | `30` |

Примеры:

```bash
sudo env IR_DIR=/var/ir ./ir_check.sh full
sudo env SSH_AUDIT_USER=admin SSH_AUDIT_HOST=server SSH_AUDIT_ADDR=192.0.2.10 ./ir_check.sh ssh
sudo env IR_ENABLE_LSOF_PROC=1 ./ir_check.sh anomalies
```

> [!NOTE]
> При использовании `sudo` переменные окружения желательно передавать через `sudo env`, потому что `sudo` может очищать окружение.

---

## 9. Контроллер `ir_check.sh`

`ir_check.sh` — основная точка входа. Он:

- создаёт каталог проверки;
- запускает отдельные скрипты;
- сохраняет ссылку `/root/ir/latest`;
- пишет прогресс выполнения;
- формирует сводку, упаковывает и экспортирует отчёт;
- запускает периодическую проверку;
- запускает очистку;
- предоставляет интерактивное меню.

### Запуск без параметров

```bash
sudo ./ir_check.sh
```

### Команды

| Команда | Назначение |
|---|---|
| `menu` | Интерактивное меню. Используется по умолчанию. |
| `setup` | Установить базовые диагностические пакеты. |
| `setup-scanners` | Установить базовые пакеты и сканеры. |
| `basic` | Базовая проверка. |
| `anomalies` | Расширенные аномалии процессов, памяти, `netns`, `/proc/net/tcp`. |
| `ssh` | Аудит SSH, если `sshd` установлен. |
| `integrity` | Проверка целостности пакетов и подозрительных файлов. |
| `modules` | Проверка модулей ядра. |
| `boot` | Проверка boot/UEFI/GRUB. |
| `network` | Проверка сети, маршрутов, firewall, DNS. |
| `scanners` | Запуск `rkhunter`, `chkrootkit`, `lynis`, если установлены. |
| `all` | Все диагностические проверки без установки пакетов. |
| `full` | Установка пакетов + все диагностические проверки. |
| `full-scanners` | Установка пакетов + сканеры + все диагностические проверки. |
| `audit-ssh` | Добавить runtime-правила аудита для SSH-конфигурации. |
| `audit-ssh-persist` | Добавить правила аудита и сохранить их в `/etc/audit/rules.d`. |
| `summarize` | Сформировать краткую сводку `99-summary.txt`. |
| `pack` | Упаковать последний отчёт. |
| `export` | Скопировать последний отчёт в домашнюю папку и исправить права. |
| `export <user> [<dir>]` | Экспорт отчёта конкретному пользователю / в указанный каталог. |
| `periodic` | Быстрая периодическая проверка со сравнением снимков. |
| `cleanup` | Показать справку по очистке. |
| `cleanup-packages` | Удалить диагностические пакеты, установленные скриптом. |
| `cleanup-audit` | Удалить правила аудита, добавленные `80_ir_audit_ssh_rules.sh`. |
| `cleanup-logs` | Удалить каталог `/root/ir`. |
| `cleanup-all` | Удалить пакеты, правила аудита и логи. |
| `latest` | Показать каталог последнего запуска. |
| `help` | Справка. |

### Интерактивное меню

```text
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

 16) Сформировать краткую сводку (99-summary.txt)
 17) Упаковать последний отчёт
 18) Экспорт отчёта в домашнюю папку
 19) Показать каталог последнего отчёта

 20) Очистка: удалить пакеты
 21) Очистка: удалить правила аудита SSH
 22) Очистка: удалить логи и состояние
 23) Очистка: всё (пакеты, аудит, логи)

 24) Периодическая проверка (быстрая)

  0) Выход
```

---

## 10. Подробное описание скриптов

### 10.1. `00_ir_setup.sh`

- создаёт каталог `/root/ir` и каталог состояния `/root/ir/state`;
- устанавливает диагностические пакеты (включая `bsd-mailx`);
- сохраняет список вновь установленных пакетов в `/root/ir/state/setup_installed_packages.txt`.

Запуск:

```bash
sudo ./00_ir_setup.sh
sudo ./00_ir_setup.sh --with-scanners
```

> [!NOTE]
> Пакеты, которые уже были установлены до запуска setup, в состояние не попадают и очисткой не удаляются.

### 10.2. `10_ir_basic.sh`

Собирает базовые артефакты: дата, версия ядра, OS release; PID 1 и его окружение; `kernel.core_pattern`; активные пользователи и история входов; дерево процессов; процессы с высоким CPU; слушающие сокеты и установленные соединения; адреса, маршруты, ARP; DNS и `/etc/hosts`; пользователи с UID 0 и с shell; привилегированные группы; `authorized_keys`; содержимое `.ssh`; активные сервисы, таймеры, включённые юниты; модули ядра; USB; PCI; хвост `dmesg`.

Лог: `10-basic.log`.

### 10.3. `15_ir_anomalies.sh`

Проверяет:

- исполняемые регионы памяти `rwxp` (анонимные, `memfd`, `(deleted)`);
- процессы с удалённым исполняемым файлом и `memfd`;
- сетевые namespace (список процессов, уникальные inode, именованные netns, контейнерные сервисы);
- открытые файловые дескрипторы к чужим `/proc/PID`;
- сравнение локальных IPv4 TCP-эндпоинтов `/proc/net/tcp` и `ss -tan`.

Файлы: `15-anomalies.log`, `netns_snapshot.txt`, `proc_tcp_local.txt`, `ss_tcp_local.txt`.

Ограничения: `rwxp` типичен для JIT (браузеры, Java, .NET, NodeJS, Qt/QML, Electron); удалённый `exe` возможен после обновления пакета; netns есть у Docker/VPN/LXC; сравнение сокетов ориентировано на IPv4 и чувствительно к кратковременным соединениям.

### 10.4. `16_ir_ssh_audit.sh`

Проверяет SSH, если установлен `sshd`; иначе корректно пропускает проверку.

Собирает: наличие `openssh-server`; статус `ssh.service`/`sshd.service`; `sshd -t`; эффективный конфиг `sshd -T`; контекстный конфиг `sshd -T -C user=...,host=...,addr=...`; параметры `Port`, `ListenAddress`, `AuthorizedKeysFile`, `AuthorizedKeysCommand`, `AuthorizedKeysCommandUser`, `TrustedUserCAKeys`, `AuthorizedPrincipalsFile`, `AuthorizedPrincipalsCommand`, `PermitRootLogin`, `PasswordAuthentication`, `PubkeyAuthentication`, `PermitEmptyPasswords`, `HostKey`, `HostCertificate`, `Include`, `Match`, `ForceCommand`; статические конфиги `/etc/ssh/sshd_config` и `/etc/ssh/sshd_config.d`; проверку файлов `AuthorizedKeysCommand`, `TrustedUserCAKeys`, `AuthorizedPrincipalsFile`; отпечатки хостовых ключей и `authorized_keys`; слушающие сокеты SSH.

Файлы: `16-ssh-audit.log`, `sshd-T.txt`, `sshd-T.err`, `sshd-T-context-*.txt`.

### 10.5. `20_ir_integrity.sh`

Проверяет: `dpkg -V`; `debsums`; источники пакетов и настройки `apt`; исполняемые файлы в `/tmp`, `/var/tmp`, `/dev/shm`; `setuid`/`setgid`; capabilities; `/etc/ld.so.preload`; упоминания `LD_PRELOAD`/`LD_AUDIT`; cron; подозрительные шаблоны в cron/systemd/shell startup; историю установки пакетов; ошибки `journalctl`; логи SSH; целостность журнала (`journalctl --verify`, ограничен timeout 300 c).

Лог: `20-integrity.log`.

> [!NOTE]
> Рекурсивный поиск по `/etc`, `/usr/lib/systemd`, `/run` выполняется через `find -type f | xargs grep`, а не через `grep -R`, чтобы не зависать на FIFO systemd (`/run/systemd/inaccessible/fifo`).

### 10.6. `30_ir_modules.sh`

Проверяет: версию ядра; `kernel taint`; `sig_enforce`; `lockdown`; `kernel.modprobe`; загруженные модули (путь, подпись, владелец по `dpkg -S`); целостность пакетов ядра; ошибки подписи в `dmesg`; файлы модулей вне `/lib/modules`; DKMS; автозагрузку модулей; недавно изменённые файлы модулей.

Лог: `30-modules.log`.

Признаки проблемы: модуль загружен, но файла нет; файл в `/tmp`, `/dev/shm`, `/home`; нет владельца пакета; ошибки подписи; модуль не принадлежит известному пакету.

### 10.7. `40_ir_boot.sh`

Проверяет: тип firmware; записи `efibootmgr`; состояние Secure Boot; MOK-ключи; командную строку ядра; содержимое `/boot`; файлы EFI System Partition; записи `/etc/fstab` для `/boot` и EFI; подозрительные строки `grub.cfg`; пользовательские настройки GRUB; информацию BIOS/UEFI (`dmidecode`); firmware security (`fwupdmgr`).

Лог: `40-boot.log`.

### 10.8. `50_ir_network.sh`

Проверяет: интерфейсы; маршруты и таблицы маршрутизации; ARP/neighbor; слушающие сокеты; установленные TCP-соединения; сетевые файлы процессов (`lsof`); `iptables`, `ip6tables`, `nftables`; DNS и резолвер; `/etc/hosts`; `nsswitch.conf`; прокси; настройки `apt` (прокси и хуки); сетевые конфигы; NetworkManager-подключения; `/etc/network/interfaces`; DHCP hooks.

Лог: `50-network.log`.

### 10.9. `60_ir_scanners.sh`

Запускает `rkhunter`, `chkrootkit`, `lynis`, если они установлены. Лог: `60-scanners.log`.

> [!WARNING]
> Сканеры могут давать ложные срабатывания и могут не обнаружить сложные угрозы. Их вывод нужно интерпретировать, а не считать безусловным вердиктом.

### 10.10. `70_ir_pack.sh`

Упаковывает `/root/ir/latest` в `/root/ir/ir_report_YYYYmmdd-HHMMSS.tar.gz` и создаёт `.sha256`.

Проверка контрольной суммы:

```bash
sha256sum -c /root/ir/ir_report_YYYYmmdd-HHMMSS.tar.gz.sha256
```

### 10.11. `75_ir_export.sh`

- находит последний архив `/root/ir/ir_report_*.tar.gz`;
- копирует его в целевой каталог (по умолчанию домашний каталог пользователя, запустившего `sudo`);
- пересоздаёт `.sha256` с относительным путём, чтобы `sha256sum -c` работал в новом каталоге;
- меняет владельца на целевого пользователя и ставит права `644`.

Запуск:

```bash
sudo ./ir_check.sh export
sudo ./ir_check.sh export antonis
sudo ./75_ir_export.sh antonis /home/antonis/Reports
```

> [!WARNING]
> Архив содержит диагностические данные (имена пользователей, пути, сетевые адреса, отпечатки ключей). Не оставляйте его в общедоступном месте и удаляйте после передачи.

### 10.12. `80_ir_audit_ssh_rules.sh`

Добавляет правила аудита (`auditctl`) для:

```text
/etc/ssh/sshd_config
/etc/ssh/sshd_config.d
AuthorizedKeysCommand
TrustedUserCAKeys
AuthorizedPrincipalsFile
```

Ключи аудита: `ssh_config`, `ssh_authorizedkeyscommand`, `ssh_trustedusercakeys`, `ssh_authorizedprincipalsfile`.

Запуск:

```bash
sudo ./ir_check.sh audit-ssh
sudo ./ir_check.sh audit-ssh-persist
sudo augenrules --load
```

Просмотр событий:

```bash
sudo ausearch -k ssh_config --start today -i
```

### 10.13. `90_ir_cleanup.sh`

Удаляет диагностические пакеты, правила аудита, логи и состояние.

| Опция | Назначение |
|---|---|
| `--packages` | Удалить пакеты, установленные скриптом проверки. |
| `--audit` | Удалить правила аудита, добавленные `80_ir_audit_ssh_rules.sh`. |
| `--logs` | Удалить каталог `/root/ir`. |
| `--all` | Выполнить всё перечисленное. |
| `--known-packages` | Использовать встроенный список пакетов, если нет файла состояния. |
| `--autoremove` | Выполнить `apt-get autoremove --purge` после удаления пакетов. |
| `--dry-run` | Только показать действия, ничего не выполнять. |
| `--force` | Не спрашивать подтверждения. |

> [!CAUTION]
> Очистка уничтожает собранные артефакты. Перед очисткой упакуйте и экспортируйте отчёт.

> [!WARNING]
> Встроенный список `--known-packages` намеренно не включает потенциально критичные пакеты, такие как `ca-certificates`. Для удаления таких пакетов используется файл состояния, если они были установлены скриптом.

### 10.14. `95_ir_summarize.sh`

Создаёт краткую сводку по логам последнего запуска: `/root/ir/latest/99-summary.txt`.

Извлекает подозрительные строки из всех логов, включая отдельные детальные блоки:

- **MODULES**: kernel taint, signature enforcement, модули без владельца пакета, модули вне `/lib/modules`, ошибки подписи, DKMS;
- **BOOT**: тип firmware, EFI boot entries, Secure Boot state, MOK-ключи, kernel cmdline, подозрительные файлы в `/boot`.

Запуск:

```bash
sudo ./ir_check.sh summarize
sudo ./95_ir_summarize.sh /root/ir/run_YYYYmmdd-HHMMSS
```

> [!NOTE]
> `99-summary.txt` не заменяет полные логи. Это точка входа для быстрого анализа и передачи результатов аналитику.

### 10.15. `99_ir_periodic.sh`

Быстрая периодическая проверка со сравнением снимков состояния.

Снимки (текущий `.list` и предыдущий `.prev`):

| Снимок | Содержимое |
|---|---|
| `setuid` | Все `setuid`/`setgid` файлы с правами и владельцами. |
| `listeners` | Слушающие TCP-сокеты с процессами. |
| `uid0` | Пользователи с UID 0. |
| `sudoers` | Хэши `/etc/sudoers` и `/etc/sudoers.d/*`. |
| `authorized_keys` | Файлы `authorized_keys` с правами и владельцами. |
| `efi_hashes` | Хэши `.efi` и `.CSV` файлов на ESP (если смонтирован). |
| `preload` | Содержимое `/etc/ld.so.preload` или `ABSENT`. |
| `modules_outside` | Файлы модулей вне `/lib/modules` и `/usr/src`. |

ALERT-условия:

- существует `/etc/ld.so.preload`;
- найдены файлы модулей вне `/lib/modules`;
- `dpkg -V` показал расхождения в критичных пакетах (`sudo`, `login`, `passwd`, `bash`, `coreutils`, `util-linux`, `systemd`, `libc6`, `openssh-server`, текущий `linux-image`);
- изменился любой критичный снимок (setuid, uid0, sudoers, authorized_keys, efi_hashes, preload, modules_outside);
- появились новые слушающие TCP на внешних интерфейсах (`0.0.0.0:`, `[::]:`, `*:`).

Дополнительно в лог попадают INFO-блоки: новые файлы автозапуска за 7 дней, процессы с удалённым `exe`, ошибки journal за 24 часа.

Результаты:

```text
/root/ir/periodic/periodic_YYYYmmdd-HHMMSS.log
/root/ir/periodic/periodic_latest.log
/root/ir/periodic/snapshots/*
```

Код возврата: `0` — отклонений нет; `1` — есть ALERTS (видно как `failed` в journal для systemd-сервиса).

Ротация: логи старше `RETENTION_DAYS` (по умолчанию 30) удаляются.

Запуск:

```bash
sudo ./ir_check.sh periodic
sudo ./99_ir_periodic.sh
```

---

## 11. Периодические проверки и мониторинг

### Systemd timer (ежедневно)

`/etc/systemd/system/debri-periodic.service`:

```ini
[Unit]
Description=DEBRI-Toolkit periodic security check
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /path/to/debri-toolkit/99_ir_periodic.sh
Nice=10
IOSchedulingClass=idle
```

`/etc/systemd/system/debri-periodic.timer`:

```ini
[Unit]
Description=Run DEBRI-Toolkit periodic check daily

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=3600

[Install]
WantedBy=timers.target
```

Активация:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now debri-periodic.timer
systemctl list-timers | grep debri
```

Если в прогоне были ALERTS, сервис будет в состоянии `failed` — это и есть сигнал посмотреть `/root/ir/periodic/periodic_latest.log`.

### Альтернатива: cron

```cron
0 3 * * * /path/to/debri-toolkit/99_ir_periodic.sh
```

---

## 12. Рекомендуемые сценарии использования

### Сценарий 1. Быстрая проверка с установкой инструментов

```bash
sudo ./ir_check.sh full
sudo ./ir_check.sh summarize
sudo ./ir_check.sh pack
sudo ./ir_check.sh export
```

### Сценарий 2. Полная проверка со сканерами

```bash
sudo ./ir_check.sh full-scanners
sudo ./ir_check.sh summarize
sudo ./ir_check.sh pack
```

### Сценарий 3. Только диагностика без установки пакетов

```bash
sudo ./ir_check.sh all
sudo ./ir_check.sh summarize
sudo ./ir_check.sh pack
```

### Сценарий 4. Проверка только SSH

```bash
sudo ./ir_check.sh ssh
sudo ./ir_check.sh summarize
```

### Сценарий 5. Проверка SSH для конкретного пользователя и адреса

```bash
sudo env SSH_AUDIT_USER=admin SSH_AUDIT_HOST=server SSH_AUDIT_ADDR=203.0.113.10 \
  ./ir_check.sh ssh
```

### Сценарий 6. Включить аудит изменений SSH

```bash
sudo ./ir_check.sh audit-ssh-persist
sudo augenrules --load
```

### Сценарий 7. Периодический мониторинг

```bash
sudo ./ir_check.sh periodic
less /root/ir/periodic/periodic_latest.log
```

### Сценарий 8. Очистка после проверки

```bash
sudo ./ir_check.sh pack
sudo ./ir_check.sh export
sudo ./90_ir_cleanup.sh --dry-run --all
sudo ./ir_check.sh cleanup-all
```

---

## 13. Как читать логи

Порядок анализа:

1. Открыть `/root/ir/latest/99-summary.txt`.
2. Посмотреть `/root/ir/latest/progress.log`.
3. При подозрительных строках открыть соответствующий полный лог и посмотреть контекст:

```bash
sed -n '100,200p' /root/ir/latest/20-integrity.log
```

4. Для мониторинга изменений смотреть `/root/ir/periodic/periodic_latest.log` и блоки `!!! ИЗМЕНЕНИЯ В ...`.

Что смотреть в каждом логе — см. разделы 10.2–10.9 и списки красных флагов ниже.

---

## 14. Красные флаги

### Высокая подозрительность

- неизвестный процесс с внешним сетевым соединением;
- процесс с удалённым `exe` и сетевой активностью;
- исполняемый файл в `/tmp`, `/var/tmp`, `/dev/shm`;
- неизвестный модуль ядра или модуль без владельца пакета;
- чужие `authorized_keys`;
- второй пользователь с UID 0;
- неизвестный пользователь в `sudo`, `docker`, `lxd`, `libvirt`, `disk`, `kvm`;
- `/etc/ld.so.preload` или `LD_PRELOAD` в системных конфигах;
- неизвестный `AuthorizedKeysCommand` или `TrustedUserCAKeys`;
- изменения системных бинарников по `dpkg -V` или `debsums`;
- неизвестные `.efi` файлы или подозрительные записи `efibootmgr`;
- ALERTS в периодических проверках без объяснимой причины.

### Умеренная подозрительность

- `rwxp` у браузера, Java, .NET, NodeJS, Qt/Electron;
- удалённый `exe` после обновления пакета;
- несколько сетевых namespace при наличии Docker/VPN;
- `AuthorizedKeysCommand`/`TrustedUserCAKeys`, используемые известной инфраструктурой.

### Низкая подозрительность

- все процессы принадлежат известным пакетам;
- файлы находятся в стандартных системных каталогах;
- `dpkg -V` не показывает изменения критичных бинарников;
- сетевые соединения объясняются сервисами;
- конфигурация SSH соответствует ожидаемой.

---

## 15. Ложные срабатывания

- `rwxp`: браузеры, Java, .NET, NodeJS, Python JIT, эмуляторы, GPU-драйверы, Qt/QML, Electron.
- Удалённый `exe`: обновление пакета, перезапуск демона, замена бинарника без перезапуска процесса.
- Сетевые namespace: Docker, Podman, LXC, libvirt, VPN, systemd-nspawn, браузерные песочницы.
- Расхождения `/proc/net/tcp` и `ss`: быстрые изменения состояния, кратковременные соединения, IPv6.
- `rkhunter`, `chkrootkit`, `lynis`: ложные срабатывания, проприетарные драйверы, устаревшие базы.
- Объекты `/dev/shm` и `/tmp` известных приложений (IPC любых клиентских программ, сервисов удалённой поддержки и т.п.).

Каждую находку нужно проверять в контексте.

---

## 16. Ограничения

- Набор не гарантирует обнаружение руткита.
- Набор не заменяет офлайн-форензику и анализ памяти.
- Проверка изнутри системы может быть скомпрометирована.
- Некоторые проверки ориентированы на Debian/Ubuntu.
- Сравнение `/proc/net/tcp` ориентировано на IPv4.
- Сканеры дают только вспомогательный результат.
- `99-summary.txt` ускоряет анализ, но не заменяет полные логи.
- Периодическая проверка сравнивает только снимки состояния и не выполняет полный триаж.

---

## 17. Офлайн-проверка с Live USB

1. Скачать официальный образ доверенного Live Linux и проверить контрольные суммы.
2. Записать образ на чистый носитель и загрузиться с него.
3. Смонтировать корневой раздел подозрительной системы только для чтения:

```bash
mount -o ro,noatime /dev/sdXn /mnt
```

Для LUKS:

```bash
cryptsetup luksOpen /dev/sdXn cryptroot
mount -o ro,noatime /dev/mapper/cryptroot /mnt
```

Для btrfs может потребоваться подтом:

```bash
mount -o ro,subvol=@ /dev/sdXn /mnt
```

4. Анализировать: `/mnt/etc`, `/mnt/var/log`, `/mnt/usr/bin`, `/mnt/usr/sbin`, `/mnt/boot`, `/mnt/boot/efi`, `/mnt/root/.ssh`, `/mnt/home/*/.ssh`.

---

## 18. Действия при инциденте

1. Не вводите важные пароли, ключи и коды 2FA на подозрительной системе.
2. Сохраните отчёт: `sudo ./ir_check.sh pack && sudo ./ir_check.sh export`.
3. Скопируйте архив на внешний носитель или доверенный хост.
4. Отключите машину от сети.
5. При необходимости сохраните образ диска или оперативную память.
6. Перейдите к офлайн-проверке с Live USB.
7. При подтверждении компрометации: переустановите систему; обновите UEFI/BIOS; удалите неизвестные загрузочные записи; смените пароли; перевыпустите SSH-ключи; отзовите токены; завершите активные сессии; проверьте роутер и сетевые настройки.

---

## 19. Диагностика типовых проблем

### `20_ir_integrity.sh` зависает на секции LD_PRELOAD / LD_AUDIT

Причина: рекурсивный `grep -R` по `/run` открывает FIFO systemd (`/run/systemd/inaccessible/fifo`) и блокируется навсегда.

Решение: в актуальной версии используется `find -type f | xargs grep`, зависание исключено. Если используется старая версия — обновите скрипт.

### `chkrootkit.service` падает с `status=127`, `mail: not found`

Причина: не установлен пакет, предоставляющий команду `mail`.

Решение: `bsd-mailx` включён в базовый список `00_ir_setup.sh`. На уже настроенной системе: `sudo apt install bsd-mailx`. Письма доставляются локально через MTA (например, exim4) в `/var/mail/root`.

### `apt-get update` завершился с ошибкой

Причины: нет сети, недоступны репозитории, неверные источники, проблемы DNS, требуется прокси. Проверки можно запустить без установки пакетов: `sudo ./ir_check.sh all`.

### `sshd -T` завершился с ошибкой

Причины: отсутствует `/etc/ssh/sshd_config`, ошибка конфигурации, отсутствуют хостовые ключи, пакет установлен частично. Проверьте `sudo sshd -t`.

### `efibootmgr` / `fwupdmgr` / `auditctl` недоступны

Установите соответствующие пакеты (`efibootmgr`, `fwupd`, `auditd`) или запустите `sudo ./ir_check.sh setup`.

### `latest` не найден

Не было выполнено ни одной проверки или каталог `/root/ir` удалён. Выполните `sudo ./ir_check.sh full` или `sudo ./ir_check.sh all`.

### Нет `99-summary.txt`

Не был запущен скрипт сводки. Выполните `sudo ./ir_check.sh summarize`.

### Очистка не удаляет пакеты

Отсутствует файл состояния, пакеты были установлены до setup, удалены вручную или используется неполный список. Проверьте `cat /root/ir/state/setup_installed_packages.txt` или используйте `--known-packages`.

---

## 20. Расширение набора

1. Создайте файл, например `55_ir_custom.sh`.
2. Используйте стиль остальных скриптов: проверка `root`; `umask 077`; каталог вывода через `IR_RUN_DIR`; запись лога через `tee`.
3. Добавьте его в `ir_check.sh` в массив `scripts` внутри функции `run_all`.
4. При необходимости добавьте отдельный пункт меню или команду.

---

## 21. Безопасность использования очистки

Рекомендуемый порядок:

1. `sudo ./ir_check.sh pack`
2. `sudo ./ir_check.sh export` и копирование архива в безопасное место
3. `sudo ./90_ir_cleanup.sh --dry-run --all`
4. `sudo ./ir_check.sh cleanup-all`

Дополнительно: `--autoremove` (зависимости), `--known-packages` (без файла состояния), `--force` (без подтверждений, только для автоматизации).

---

## 22. Рекомендации по hardening после проверки

- Включите файрвол с политикой `default deny incoming` (ufw/nftables); открывайте только осознанно нужные порты и только из локальной подсети.
- Отключите и выведите из автозагрузки сервисы удалённого доступа, которые не используются постоянно (AnyDesk, TeamViewer, сервисы поддержки, TFTP, KDE Connect и т.п.).
- Если SSH-сервер не нужен — не устанавливайте `openssh-server`; удалите остатки `authorized_keys`.
- При невозможности включить Secure Boot компенсируйте это: пароль UEFI на изменение настроек (не Power-On, если нужен WoL), пароль GRUB на редактирование cmdline (`--unrestricted` для обычной загрузки), LUKS для шифрования диска.
- Удалите неиспользуемые загрузочные записи UEFI (`efibootmgr -b XXXX -B`) и остатки других ОС на ESP.
- Держите ESP смонтированным согласно `/etc/fstab` (иначе обновления GRUB/shim могут завершиться ошибкой).
- Периодически проверяйте целостность EFI-файлов и сравнивайте снимки `99_ir_periodic.sh`.

---

## 23. Часто задаваемые вопросы

**Можно ли использовать набор на сервере?** Да, но ресурсоёмкие проверки (`15`, `20`, `60`, `lsof +D /proc`) тестируйте в нерабочее время.

**Можно ли использовать без интернета?** Да, но без установки пакетов часть функций недоступна; используйте `sudo ./ir_check.sh all`.

**Проверяется ли система на вирусы?** Нет, это не антивирус. Набор собирает артефакты и ищет подозрительные шаблоны.

**Можно ли отправлять архив с логами?** Да, но сначала проверьте конфиденциальность. Для первичной отправки лучше использовать `99-summary.txt`.

**Почему `rkhunter`/`chkrootkit` что-то нашли?** Это может быть ложное срабатывание, легитимное изменение, проприетарный драйвер, обновление пакета или реальный индикатор. Проверяйте в совокупности с другими логами.

**Почему `rwxp` у браузера или KDE-приложений?** JIT и QML-движки создают исполняемые регионы памяти. Сам по себе `rwxp` не доказательство взлома.

**Почему `deleted exe` у системного процесса?** Часто это следствие обновления пакета. Подозрительно, только если процесс неизвестный, сетевой или запущен из нестандартного каталога.

**Зачем нужен `bsd-mailx` в setup?** Чтобы `chkrootkit-daily` мог отправить отчёт на root вместо падения с `mail: not found`.

---

## 24. История изменений

### v1.1 (2026-11-24)

- Добавлен `75_ir_export.sh` и команды `export` / `export-report` / `copy-report`.
- Добавлен `95_ir_summarize.sh` с детализированными блоками MODULES и BOOT; команда `summarize`.
- Добавлен `99_ir_periodic.sh` (снимки состояния, сравнение, ALERTS, ротация) и команда `periodic`; примеры systemd timer и cron.
- Контроллер: прогресс выполнения (`progress_line`, `progress.log`), меню расширено до пункта 24.
- `00_ir_setup.sh`: в базовый список пакетов добавлен `bsd-mailx`.
- `20_ir_integrity.sh`: исправлено зависание рекурсивного grep на FIFO в `/run` (переход на `find -type f | xargs grep`); `journalctl --verify` ограничен timeout 300 c.
- Экспорт отчёта пересоздаёт `.sha256` с относительным путём для удобства проверки в новом каталоге.

### v1.0 (2026-11-22)

- Первичный выпуск: скрипты 00–90, контроллер `ir_check.sh`, базовая документация.

---

## 25. Лицензия

MIT + Commons Clause.

- Исходный код открыт, доработка разрешена.
- Продажа и перепродажа скрипта или его модификаций ЗАПРЕЩЕНА всем, кроме правообладателя.
- При использовании в любых платных или бесплатных системах ОБЯЗАТЕЛЬНО явное указание автора: **Глазов Андрей / JunDevPy**.

Copyright (c) 2026 Глазов Андрей / JunDevPy. Original source: <https://github.com/JunDevPy/debri-toolkit>
