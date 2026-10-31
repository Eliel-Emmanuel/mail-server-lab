#!/usr/bin/env bash
# collect-configs.sh - rassemble les fichiers de configuration d'une VM du labo
# pour le dossier configs/ du dépôt, en retirant tous les secrets.
#
# Usage (sur la VM, en tant qu'emma) :   sudo bash collect-configs.sh
# Résultat :                             ~/configs-<machine>.tar.gz
#
# Ce qui n'est JAMAIS copié : clés privées (TLS, DKIM, CA), /etc/dovecot/users.
# Ce qui est masqué : hash de l'interface Rspamd, des_key de Roundcube.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Erreur : à lancer avec sudo" >&2; exit 1; }

HOST=$(hostname -s)
OWNER=${SUDO_USER:-emma}
OWNER_HOME=$(getent passwd "$OWNER" | cut -d: -f6)
WORK=$(mktemp -d)
OUT="$WORK/$HOST"
ARCHIVE="$OWNER_HOME/configs-$HOST.tar.gz"
mkdir -p "$OUT"
trap 'rm -rf "$WORK"' EXIT

missing=0

# copie <source> <dossier de destination relatif>
copie() {
  local src=$1 dest="$OUT/$2"
  if [[ -f $src ]]; then
    mkdir -p "$dest"
    cp "$src" "$dest/"
    echo "  + $src"
  else
    echo "  - absent : $src"
    missing=$((missing + 1))
  fi
}

echo "Collecte sur $HOST"

# --- Communs aux deux VM ---
copie /etc/netplan/50-cloud-init.yaml          netplan
copie /etc/ssh/sshd_config.d/10-lab.conf       ssh
copie /etc/hosts                               system
copie /etc/postfix/main.cf                     postfix
copie /etc/postfix/master.cf                   postfix
copie /etc/aliases                             postfix
copie /etc/redis/redis.conf                    redis
copie /usr/local/share/ca-certificates/lab-test-ca.crt   tls
for f in /etc/ssl/certs/mail.*.fullchain.pem; do [[ -e $f ]] && copie "$f" tls; done
for f in /etc/rspamd/local.d/*; do [[ -f $f ]] && copie "$f" rspamd/local.d; done
ufw status verbose > "$OUT/system/ufw-status.txt" 2>&1 || true
postconf -n > "$OUT/postfix/postconf-n.txt"

# --- Propres à la VM mail ---
if [[ $HOST == mail ]]; then
  copie /etc/dnsmasq.d/lab.conf                dnsmasq
  copie /etc/postfix/vmailbox                  postfix
  copie /etc/postfix/virtual                   postfix
  for f in 10-auth.conf 10-logging.conf 10-mail.conf 10-master.conf 10-ssl.conf \
           15-lda.conf 15-mailboxes.conf 20-lmtp.conf 20-managesieve.conf \
           90-sieve.conf auth-lab.conf.ext; do
    copie "/etc/dovecot/conf.d/$f"             dovecot/conf.d
  done
  copie /etc/dovecot/sieve/spam-to-junk.sieve  dovecot/sieve
  copie /usr/local/sbin/mailuser.sh            scripts
  copie /etc/fail2ban/jail.d/mail-lab.local    fail2ban
  copie /etc/apache2/sites-available/webmail.lab.test.conf  apache
  copie /etc/apache2/conf-available/security.conf           apache
  copie /etc/roundcube/config.inc.php          roundcube
  if [[ -f /etc/roundcube/plugins/managesieve/config.inc.php ]]; then
    mkdir -p "$OUT/roundcube"
    cp /etc/roundcube/plugins/managesieve/config.inc.php "$OUT/roundcube/managesieve.config.inc.php"
    echo "  + /etc/roundcube/plugins/managesieve/config.inc.php"
  fi
  doveconf -n > "$OUT/dovecot/doveconf-n.txt" 2>/dev/null || true

  # Exemple de fichier des utilisateurs : adresses gardées, hashs masqués
  if [[ -f /etc/dovecot/users ]]; then
    sed -E 's/^([^:]+):.*/\1:{BLF-CRYPT}<REDACTED>/' /etc/dovecot/users > "$OUT/dovecot/users.example"
    echo "  + /etc/dovecot/users (hashs masqués -> users.example)"
  fi
fi

# --- Masquage des secrets ---
if [[ -f $OUT/rspamd/local.d/worker-controller.inc ]]; then
  sed -i -E 's/^([[:space:]]*(enable_)?password[[:space:]]*=[[:space:]]*).*/\1"<REDACTED>";/' \
    "$OUT/rspamd/local.d/worker-controller.inc"
fi
if [[ -f $OUT/roundcube/config.inc.php ]]; then
  sed -i -E "s/^([[:space:]]*\\\$config\['des_key'\][[:space:]]*=[[:space:]]*).*/\1'<REDACTED>';/" \
    "$OUT/roundcube/config.inc.php"
fi

# --- Contrôle final : aucune clé privée ni secret connu ---
if grep -rlE 'BEGIN [A-Z ]*PRIVATE KEY|\{BLF-CRYPT\}\$|\$2[aby]?\$' "$OUT" ; then
  echo "ARRÊT : un secret est encore présent dans les fichiers ci-dessus." >&2
  exit 2
fi

tar -C "$WORK" -czf "$ARCHIVE" "$HOST"
chown "$OWNER": "$ARCHIVE"
chmod 600 "$ARCHIVE"

echo
echo "Archive : $ARCHIVE"
echo "Fichiers absents : $missing (normal pour les composants non installés sur cette VM)"
