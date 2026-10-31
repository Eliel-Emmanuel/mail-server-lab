# Sécurité : choix, compromis assumés et limites

Ce document décrit les mesures de sécurité du laboratoire, les secrets et la façon dont ils sont protégés, et les compromis faits **volontairement** parce qu'il s'agit d'un environnement d'apprentissage.

## 1. Exigences et mise en œuvre

| ID | Exigence | Mise en œuvre | Preuve |
| --- | --- | --- | --- |
| ES1 | Aucun relais ouvert | `mynetworks = 127.0.0.0/8` ; `reject_unauth_destination` ; ports 465/587 : `permit_sasl_authenticated, reject` | `554 5.7.1 Relay access denied` depuis la VM `autre` ([tests/etape-08.md](tests/etape-08.md)) |
| ES2 | TLS obligatoire pour les utilisateurs | `smtpd_tls_auth_only = yes` ; 587 en `encrypt`, 465 en TLS implicite ; IMAP 143 fermé (`port = 0`) ; HTTP redirigé vers HTTPS | `530 Must issue a STARTTLS command first` ([tests/etape-07.md](tests/etape-07.md)) |
| ES2 | TLS opportuniste entre serveurs | Port 25 en `smtpd_tls_security_level = may`, comme en production | `TLS connection established` dans les deux sens |
| ES3 | Maildir protégés | Dossiers `700`, fichiers `600`, propriétaire unique `vmail` (UID/GID 5000) | `stat` ([tests/etape-06.md](tests/etape-06.md)) |
| ES4 | Pare-feu minimal | ufw : tout refusé en entrée ; ouverts sur `enp0s8`, depuis `192.168.56.0/24` uniquement : 22, 25, 53, 80, 443, 465, 587, 993 | `ufw status`, `Test-NetConnection` |
| ES5 | Mots de passe hachés | Boîtes : BLF-CRYPT (`doveadm pw`) ; interface Rspamd : hash `rspamadm pw` | Fichiers sans mot de passe en clair |
| ES6 | Administration non exposée | Interface Rspamd sur `127.0.0.1:11334`, accessible par tunnel SSH uniquement | `ss -ltnp` |
| ES7 | Pas de comptes système pour les boîtes | Migration vers des utilisateurs virtuels ; anciens comptes supprimés | `getent passwd` vide |
| ES8 | Webmail maintenu | Roundcube du dépôt Ubuntu (mises à jour par `apt`) ; RainLoop exclu | `apt policy roundcube` |
| ES9 | Anti-force-brute | Fail2ban : prisons `sshd`, `postfix-sasl`, `dovecot`, `roundcube-auth` ; 5 échecs en 10 min → 10 min de blocage via ufw | Blocage démontré depuis `autre` ([tests/etape-11.md](tests/etape-11.md)) |
| ES10 | Horloge synchronisée | `systemd-timesyncd` | `timedatectl` |
| ES11 | Services internes en local | Redis, ManageSieve (4190), Rspamd (11332-11334) sur `127.0.0.1` | `ss -ltnp` |

Autres mesures : SSH par clé uniquement, `root` interdit ; en-têtes HTTP de sécurité (`nosniff`, `SAMEORIGIN`, `Referrer-Policy`) ; `ServerTokens Prod` ; protocoles TLS limités à 1.2 et 1.3 ; DMARC `p=reject` pour `lab.test` ; Rspamd retire les en-têtes d'analyse venus de l'extérieur avant d'ajouter les siens.

## 2. Secrets du projet

| Secret | Emplacement | Traitement dans ce dépôt |
| --- | --- | --- |
| Clé privée de la CA | Poste hôte uniquement, jamais sur une VM | **Absente** du dépôt |
| Clés privées TLS des serveurs | `/etc/ssl/private/` (`600 root`) | Absentes de `configs/` |
| Clé privée DKIM | `/var/lib/rspamd/dkim/` (`440 _rspamd`) | Idem ; seule la clé **publique** (TXT DNS) est publiée |
| Hashs des boîtes | `/etc/dovecot/users` (`640 root:dovecot`) | Absent de `configs/` |
| Hash de l'interface Rspamd | `local.d/worker-controller.inc` | Remplacé par `<REDACTED>` dans `configs/` |
| `des_key` de Roundcube | `/etc/roundcube/config.inc.php` | Remplacée par `<REDACTED>` dans `configs/` |

Contrôle avant chaque publication :

```bash
git grep -nE -e 'BEGIN [A-Z ]*PRIVATE KEY' -e '\{BLF-CRYPT\}\$' -e "des_key'\] = '[^<]" -e 'password = "\$2' -- . ':!SECURITY.md'
```

Aucune sortie attendue.

## 3. Compromis assumés

| Compromis | Raison dans le laboratoire | En production |
| --- | --- | --- |
| `milter_default_action = accept` | Une panne de Rspamd ne doit pas bloquer les tests | `tempfail` : refus temporaire, l'expéditeur réessaie |
| `local_addrs = 127.0.0.0/8` dans Rspamd | Les deux VM partagent un réseau privé ; sans ce réglage, `autre` serait jugée « interne » et rien ne serait vérifié | Inutile : les serveurs distants ont des adresses publiques |
| En-têtes `X-Spamd-Result` sur le courrier sortant | Pédagogique : voir le score de chaque message | Souvent retirés du courrier sortant |
| `doveadm pw -p` dans `mailuser.sh` | Le mot de passe apparaît brièvement dans la liste des processus ; acceptable sur une VM à un seul administrateur | Lecture sur l'entrée standard |
| Pas de HSTS sur le webmail | Le navigateur le mémoriserait et gênerait les retours par instantané | HSTS activé |
| `bantime` de 10 minutes | Ne pas rester bloqué pendant les tests | Bannissements longs et progressifs |
| Poste hôte absent de `ignoreip` | Aucune adresse n'est de confiance par principe ; les tests se font depuis `autre` | Idem |

## 4. Limites connues

- Pas d'antivirus (ClamAV exclu pour des raisons de mémoire).
- Pas de supervision ni d'alertes ; pas de sauvegarde externalisée des Maildir.
- La CA est locale : sa compromission permettrait de fabriquer des certificats de confiance pour le poste hôte. Sa clé reste hors des VM et hors du dépôt.
- Rapports DMARC non exploités.
- IPv6 désactivé dans Postfix ; non étudié.
