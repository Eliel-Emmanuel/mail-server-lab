# Configurations réelles des VM

Fichiers récupérés tels quels sur les deux VM avec [`scripts/collect-configs.sh`](../scripts/collect-configs.sh), après validation de chaque étape.

```text
configs/
├── mail/      # mail.lab.test : postfix, dovecot, rspamd, redis, dnsmasq, apache, roundcube, fail2ban, ssh, netplan, tls (public)
└── autre/     # mail.autre.test : postfix, rspamd, redis, ssh, netplan, tls (public)
```

**Aucun secret ici** :

| Élément | Traitement |
| --- | --- |
| Clés privées TLS, DKIM, CA | Jamais collectées |
| `/etc/dovecot/users` | Remplacé par `dovecot/users.example` (adresses gardées, hashs masqués) |
| Hash de l'interface Rspamd | `<REDACTED>` |
| `des_key` de Roundcube | `<REDACTED>` |

Les fichiers `postconf-n.txt` et `doveconf-n.txt` donnent la configuration effective, limitée aux valeurs différentes des valeurs par défaut : c'est le plus rapide à lire.

Pour mettre à jour après une modification sur une VM : relancer la collecte, puis comparer avec `git diff configs/`.
