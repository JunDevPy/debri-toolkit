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
  echo "[!] Запускать от root: sudo ./16_ir_ssh_audit.sh"
  exit 1
fi

IR_DIR="${IR_DIR:-/root/ir}"

if [[ -n "${IR_RUN_DIR:-}" ]]; then
  OUT_DIR="$IR_RUN_DIR"
else
  OUT_DIR="$IR_DIR/run_$(date +%Y%m%d-%H%M%S)"
fi

mkdir -p "$OUT_DIR"
LOG="$OUT_DIR/16-ssh-audit.log"

{
  echo "=== SCRIPT: 16_ir_ssh_audit.sh ==="
  date
  echo

  SSHD_BIN=$(command -v sshd 2>/dev/null || true)

  if [[ -z "$SSHD_BIN" && -x /usr/sbin/sshd ]]; then
    SSHD_BIN="/usr/sbin/sshd"
  fi

  echo "=== SSH SERVER PRESENCE ==="
  dpkg -l openssh-server 2>/dev/null | tail -n +6 || true
  echo

  if [[ -z "$SSHD_BIN" ]]; then
    echo "sshd binary not found."
    echo "SSH server likely not installed."
    echo "Skipping SSH-specific checks."
  else
    echo "sshd binary: $SSHD_BIN"
    echo

    echo "=== SSH SERVICE UNIT STATUS ==="
    systemctl list-unit-files 2>/dev/null | grep -Ei 'ssh|sshd' || true
    echo

    for unit in ssh.service sshd.service; do
      echo "--- $unit ---"
      systemctl is-enabled "$unit" 2>/dev/null || true
      systemctl is-active "$unit" 2>/dev/null || true
      echo
    done

    echo "=== sshd -t CONFIG TEST ==="
    "$SSHD_BIN" -t 2>&1 || true
    echo

    SSHD_T="$OUT_DIR/sshd-T.txt"
    SSHD_T_ERR="$OUT_DIR/sshd-T.err"

    echo "=== sshd -T EFFECTIVE CONFIG DUMP ==="
    if "$SSHD_BIN" -T > "$SSHD_T" 2> "$SSHD_T_ERR"; then
      echo "sshd -T OK"
    else
      echo "sshd -T failed. Error output:"
      cat "$SSHD_T_ERR" 2>/dev/null || true
    fi
    echo

    if [[ -s "$SSHD_T" ]]; then
      echo "=== IMPORTANT EFFECTIVE SSHD OPTIONS ==="
      grep -Ei '^(port|listenaddress|authorizedkeysfile|authorizedkeyscommand|authorizedkeyscommanduser|trustedusercakeys|authorizedprincipalsfile|authorizedprincipalscommand|permitrootlogin|passwordauthentication|pubkeyauthentication|permitemptypasswords|hostkey|hostcertificate|match|include|forcecommand|allowtcpforwarding|x11forwarding|permittunnel|permittty)' \
        "$SSHD_T" || true
      echo

      SSH_AUDIT_USER="${SSH_AUDIT_USER:-root}"
      SSH_AUDIT_HOST="${SSH_AUDIT_HOST:-localhost}"
      SSH_AUDIT_ADDR="${SSH_AUDIT_ADDR:-127.0.0.1}"

      ctx_suffix=$(printf '%s' "$SSH_AUDIT_USER" | tr -c 'A-Za-z0-9._-' '_')
      CTX_OUT="$OUT_DIR/sshd-T-context-${ctx_suffix}.txt"
      CTX_ERR="$OUT_DIR/sshd-T-context-${ctx_suffix}.err"

      echo "=== sshd -T MATCH CONTEXT ==="
      echo "user=$SSH_AUDIT_USER host=$SSH_AUDIT_HOST addr=$SSH_AUDIT_ADDR"
      echo

      if "$SSHD_BIN" -T -C "user=$SSH_AUDIT_USER,host=$SSH_AUDIT_HOST,addr=$SSH_AUDIT_ADDR" \
           > "$CTX_OUT" 2> "$CTX_ERR"; then

        grep -Ei '^(port|authorizedkeysfile|authorizedkeyscommand|authorizedkeyscommanduser|trustedusercakeys|authorizedprincipalsfile|authorizedprincipalscommand|permitrootlogin|passwordauthentication|pubkeyauthentication|forcecommand|permittty|x11forwarding)' \
          "$CTX_OUT" || true
      else
        echo "sshd -T -C failed. Error output:"
        cat "$CTX_ERR" 2>/dev/null || true
      fi
      echo

      echo "=== STATIC SSH CONFIG FILES ==="
      ls -l /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null || true
      echo

      echo "=== STATIC CONFIG IMPORTANT DIRECTIVES ==="
      grep -RniE '^[[:space:]]*(Include|Match|AuthorizedKeysCommand|AuthorizedKeysFile|AuthorizedKeysCommandUser|TrustedUserCAKeys|AuthorizedPrincipalsFile|AuthorizedPrincipalsCommand|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|ForceCommand|HostKey|HostCertificate|Port|ListenAddress)' \
        /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null \
        | head -n 400 || true
      echo

      echo "=== PARSED EFFECTIVE PATHS ==="
      port=$(sed -n 's/^port //p' "$SSHD_T" | head -n 1)
      akf=$(sed -n 's/^authorizedkeysfile //p' "$SSHD_T" | head -n 1)
      akc=$(sed -n 's/^authorizedkeyscommand //p' "$SSHD_T" | head -n 1)
      akc_user=$(sed -n 's/^authorizedkeyscommanduser //p' "$SSHD_T" | head -n 1)
      ca=$(sed -n 's/^trustedusercakeys //p' "$SSHD_T" | head -n 1)
      apf=$(sed -n 's/^authorizedprincipalsfile //p' "$SSHD_T" | head -n 1)

      echo "port=$port"
      echo "authorizedkeysfile=$akf"
      echo "authorizedkeyscommand=$akc"
      echo "authorizedkeyscommanduser=$akc_user"
      echo "trustedusercakeys=$ca"
      echo "authorizedprincipalsfile=$apf"
      echo

      if [[ -n "$akc" && "$akc" != "none" ]]; then
        echo "=== AuthorizedKeysCommand CHECK ==="
        echo "Raw value: $akc"

        akc_bin=$(awk '{print $1}' <<< "$akc")
        echo "Binary: $akc_bin"

        if [[ -e "$akc_bin" ]]; then
          ls -l "$akc_bin" || true
          stat -c 'mode=%a owner=%U:%G' "$akc_bin" 2>/dev/null || true

          find "$(dirname "$akc_bin")" -maxdepth 1 -type f -name "$(basename "$akc_bin")" \
            \( ! -user root -o -perm -0022 \) -ls 2>/dev/null || true
        else
          echo "AuthorizedKeysCommand binary not found."
        fi
        echo
      fi

      if [[ -n "$ca" && "$ca" != "none" ]]; then
        echo "=== TrustedUserCAKeys CHECK ==="
        echo "Raw value: $ca"

        if [[ -f "$ca" ]]; then
          ls -l "$ca" || true
          stat -c 'mode=%a owner=%U:%G' "$ca" 2>/dev/null || true

          if command -v ssh-keygen >/dev/null 2>&1; then
            ssh-keygen -lf "$ca" 2>/dev/null || true
          else
            echo "ssh-keygen unavailable"
          fi
        else
          echo "TrustedUserCAKeys file not found."
        fi
        echo
      fi

      if [[ -n "$apf" && "$apf" != "none" ]]; then
        echo "=== AuthorizedPrincipalsFile CHECK ==="
        echo "Raw value: $apf"

        if [[ -f "$apf" ]]; then
          ls -l "$apf" || true
          stat -c 'mode=%a owner=%U:%G' "$apf" 2>/dev/null || true
        else
          echo "AuthorizedPrincipalsFile file not found."
        fi
        echo
      fi
    fi

    echo "=== SSH HOST KEYS ==="
    ls -l /etc/ssh/ssh_host_* 2>/dev/null || true
    echo

    if command -v ssh-keygen >/dev/null 2>&1; then
      for pub in /etc/ssh/ssh_host_*.pub; do
        if [[ -f "$pub" ]]; then
          echo "--- $pub ---"
          ssh-keygen -lf "$pub" 2>/dev/null || true
          echo
        fi
      done
    else
      echo "ssh-keygen unavailable"
    fi

    echo "=== AUTHORIZED_KEYS FINGERPRINTS ==="
    if command -v ssh-keygen >/dev/null 2>&1; then
      find /root /home -type f -name authorized_keys -print \
        -exec ssh-keygen -lf {} \; 2>/dev/null | head -n 400 || true
    else
      echo "ssh-keygen unavailable"
    fi
    echo

    echo "=== SSH LISTENING SOCKETS ==="
    ss -tulpn 2>/dev/null | grep -Ei 'sshd|:22\b' || true
    echo
  fi

} 2>&1 | tee "$LOG"

echo "[+] Saved: $LOG"
