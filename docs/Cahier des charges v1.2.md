# Cahier des charges — Laboratoire de serveur de messagerie auto-hébergé

Oct 31, 2026 ·

Version 1.2 : le cahier des charges est aligné sur la réalisation. Les étapes 1 à 12 sont livrées et prouvées ; l'automatisation Ansible (étape 13) reste à réaliser.

## Fiche d'identification

| Rubrique | Valeur |
| --- | --- |
| Projet | Laboratoire de serveur de messagerie auto-hébergé |
| Référence | MSL-CDC-001 |
| Version | 1.2 |
| Statut | Validé ; étapes 1 à 12 réalisées, étape 13 à réaliser |
| Auteur et réalisateur | Apovo Emmanuel Eliel |
| Nature | Projet d'apprentissage et de portfolio, environnement de laboratoire fermé |
| Dépôt associé | GitHub `mail-server-lab` (public, sans secret) |
| Diffusion | Publique |

**Historique des versions**

| Version | Date | Modifications |
| --- | --- | --- |
| 1.2 | 31/10/2026 | Alignement sur la réalisation : versions installées, comptes réels, statut des exigences et de la recette, risques constatés, glossaire |
| 1.1 | 27/10/2026 | Arbitrage des choix ouverts, dimensionnement pour le poste réel, ordre des étapes corrigé, seconde VM obligatoire |
| 1.0 | Octobre 2026 | Version initiale |

## 1. Contexte et objet

Le projet conçoit, déploie et documente une messagerie complète sous Linux dans un laboratoire de deux machines virtuelles VirtualBox. Il vise la compréhension de chaque composant d'une messagerie professionnelle, pas la mise en production.

Composants étudiés : acheminement SMTP, stockage Maildir, accès IMAP, authentification, chiffrement TLS, authenticité des messages (SPF, DKIM, DMARC), filtrage anti-spam, protection contre la force brute et webmail.

Le laboratoire est retenu plutôt qu'un serveur public pour trois raisons :

- coût nul et retour arrière immédiat grâce aux instantanés de VM ;
- aucune exposition à Internet pendant l'apprentissage ;
- reconstruction rapide d'une VM pour tester l'automatisation.

En contrepartie, certains aspects de la production ne sont pas reproductibles ; ils sont listés en section 12.

## 2. Objectifs

Chaque objectif est mesurable ; l'indicateur dit ce qui permet de le déclarer atteint.

| ID | Type | Objectif | Indicateur de réussite |
| --- | --- | --- | --- |
| OP1 | Pédagogique | Comprendre le chemin d'un e-mail : MUA → MSA → MTA → MDA → Maildir → client IMAP | Schéma d'architecture et trace d'un message dans les journaux |
| OP2 | Pédagogique | Expliquer chaque paramètre de Postfix et de Dovecot | Configurations commentées, `postconf -n` et `doveconf -n` publiés |
| OP3 | Pédagogique | Diagnostiquer par les journaux et les outils en ligne de commande | Section « Problèmes rencontrés » renseignée à chaque étape |
| OP4 | Pédagogique | Distinguer comptes système et utilisateurs virtuels | Migration réalisée, anciens comptes supprimés |
| OP5 | Pédagogique | Comprendre SPF, DKIM et DMARC | Résultats `pass` lus par l'autre domaine, usurpation refusée |
| OT1 | Technique | Messagerie fonctionnelle pour `alice@lab.test` et `mbsuser@lab.test` | Envoi, réception, lecture et classement réussis |
| OT2 | Technique | Échanges avec un second domaine, `autre.test` | Messages remis dans les deux sens, chiffrés |
| OT3 | Technique | Serveur protégé | Exigences ES1 à ES11 vérifiées |
| OT4 | Technique | Webmail en HTTPS | Accès sans avertissement, filtres Sieve actifs |
| PF1 | Portfolio | Documentation claire, reproductible et honnête sur ses limites | Dépôt public avec une page et une fiche de preuves par étape |
| PF2 | Portfolio | Reconstruction automatisée | Playbook Ansible sur VM vierges, second passage `changed=0` |

## 3. Périmètre

La version 1 couvre une messagerie complète pour un domaine, vérifiée depuis un second domaine ; tout ce qui exige Internet est exclu.

| Inclus | Exclus (et raison) |
| --- | --- |
| Postfix, Dovecot, Rspamd, Redis, Apache, PHP-FPM, Roundcube, Fail2ban installés et configurés à la main | Mise en ligne sur un VPS avec domaine public : hors laboratoire |
| Seconde VM `autre.test` (Postfix, Rspamd) pour les échanges et vérifications | Tests de délivrabilité vers Gmail ou Outlook : nécessitent Internet |
| DNS local (dnsmasq) et autorité de certification locale (OpenSSL) | Antivirus ClamAV : mémoire insuffisante sur un hôte de 8 Go |
| Comptes système, puis migration vers des utilisateurs virtuels | POP3 : IMAP couvre le besoin |
| Tests fonctionnels et de sécurité en environnement fermé | IPv6 : désactivé, choix documenté |
| Documentation GitHub, puis automatisation Ansible | Haute disponibilité, MX secondaire, quotas, conformité réglementaire |

Les exclusions restent des évolutions possibles (section 14).

## 4. Environnement

Le laboratoire tourne sur un HP EliteBook 840 G8 ; ses 8 Go de RAM limitent les VM à 4,5 Go au total et excluent ClamAV.

**4.1 Poste hôte**

| Élément | Valeur |
| --- | --- |
| Matériel | HP EliteBook 840 G8, Intel Core i5 11e génération (4 cœurs, 8 threads), 8 Go de RAM |
| Système | Windows ; virtualisation Intel VT-x activée |
| Hyperviseur | VirtualBox 7.x |
| Outils | PowerShell (SSH, SCP), Thunderbird, navigateur, VS Code, Git |
| Clé de la CA | `Documents\lab-ca`, jamais copiée sur une VM |

**4.2 Machines virtuelles**

| VM | Nom | vCPU | RAM | Disque | Rôle |
| --- | --- | --- | --- | --- | --- |
| `mail` | `mail.lab.test` | 2 | 3 Go | 25 Go dynamique | Serveur de `lab.test` : Postfix, Dovecot, Rspamd, Redis, Apache, PHP-FPM, Roundcube, dnsmasq, Fail2ban |
| `autre` | `mail.autre.test` | 1 | 1,5 Go | 12 Go dynamique | Serveur distant de `autre.test` : Postfix, Rspamd, Redis |
| `ctrl` (étape 13) | — | 1 | 1 Go | Clone de la base | Contrôleur Ansible, allumé pendant les déploiements seulement |

Système invité : Ubuntu Server 24.04.5 LTS, installation minimale. `autre` est un clone de l'instantané de base de `mail`. Un instantané est pris avant chaque étape, VM éteinte.

**4.3 Réseau**

| Machine | Carte 1 : NAT (`enp0s3`) | Carte 2 : réseau privé hôte (`enp0s8`) |
| --- | --- | --- |
| `mail` | DHCP, accès aux dépôts | `192.168.56.10/24` fixe |
| `autre` | DHCP | `192.168.56.20/24` fixe |
| `ctrl` | DHCP | `192.168.56.5/24` fixe |
| Poste hôte | — | `192.168.56.1` |

Une seule route par défaut, par la carte NAT. Le trafic de messagerie entre VM passe uniquement par le réseau privé hôte.

**4.4 Nommage, DNS et comptes**

- Domaines `lab.test` et `autre.test` (suffixe réservé aux essais) ; noms `mail.lab.test`, `webmail.lab.test`, `mail.autre.test`.
- dnsmasq, sur `mail`, sert les deux zones : enregistrements A, MX, PTR et TXT (SPF, DKIM, DMARC). `autre` l'utilise comme résolveur.
- `systemd-resolved` est désactivé ; `/etc/resolv.conf` pointe vers `127.0.0.1`. Le poste hôte résout `mail.lab.test` et `webmail.lab.test` par son fichier `hosts`.
- Compte d'administration `emma`, sur toutes les VM, accessible par clé SSH uniquement.
- Boîtes de test : `alice@lab.test` et `mbsuser@lab.test` (utilisateurs virtuels), `test@autre.test` (compte système sans shell sur `autre`).
- Fuseau horaire Africa/Porto-Novo, horloge synchronisée par `systemd-timesyncd`.

## 5. Architecture et pile logicielle

La VM `mail` porte toute la messagerie de `lab.test` ; la VM `autre` joue le serveur distant qui reçoit les messages signés et les vérifie.

&#91;embedded content: architecture du laboratoire · 2 VM, 10 composants\]

| Composant | Version installée | VM | Rôle |
| --- | --- | --- | --- |
| Ubuntu Server | 24.04.5 LTS | toutes | Système d'exploitation |
| Postfix | 3.8.6 | `mail`, `autre` | MTA (port 25) et MSA (soumission authentifiée sur 465 et 587) |
| Dovecot | 2.3.21 | `mail` | IMAPS (993), livraison LMTP, authentification SASL pour Postfix, Sieve |
| Rspamd + Redis | 4.2.3 (dépôt officiel) | `mail`, `autre` | Anti-spam ; signature DKIM sur `mail`, vérification SPF, DKIM et DMARC |
| Apache + PHP-FPM | PHP 8.3 | `mail` | Serveur web, exécution de PHP hors d'Apache |
| Roundcube | 1.6.6 (paquet Ubuntu, base SQLite) | `mail` | Webmail, filtres Sieve via ManageSieve |
| dnsmasq | paquet Ubuntu | `mail` | DNS des zones `lab.test` et `autre.test` |
| Fail2ban + ufw | Fail2ban 1.0.2 | `mail` | Pare-feu et blocage des tentatives répétées |
| OpenSSL | — | poste hôte | Autorité de certification « Lab Test Root CA » |
| Outils de test | — | hôte et VM | `swaks`, `openssl s_client`, `dig`, `doveadm`, `postqueue`, `fail2ban-regex` |

## 6. Choix techniques arrêtés

Tous les choix ouverts sont tranchés et appliqués ; chacun reste réversible par instantané.

| Décision | Choix appliqué | Justification |
| --- | --- | --- |
| Système | Ubuntu Server 24.04.5 LTS | Maturité, documentation abondante, dépôts tiers à jour |
| Comptes | Système au départ (étapes 4-5), puis virtuels (étape 6) | Comprendre la différence, puis adopter la pratique de production |
| Stockage des comptes virtuels | Fichier `/etc/dovecot/users` + tables `hash` de Postfix | Aucune base de données à faire tourner dans 3 Go ; SQL reporté en évolution |
| Hachage des mots de passe | BLF-CRYPT (bcrypt), généré par `doveadm pw` | Lent par conception, supporté nativement |
| Livraison | Postfix → Dovecot par LMTP (socket Unix) | Dovecot gère seul les Maildir et Sieve |
| Propriétaire des Maildir | Compte `vmail` (UID/GID 5000), `/var/mail/vhosts/<domaine>/<utilisateur>/` | Un seul propriétaire, aucun accès des comptes système |
| Gestion des comptes | Script `mailuser.sh` (ajout, mot de passe, suppression, liste) | Simple, versionné, reproduit ensuite par Ansible |
| Certificats | CA locale OpenSSL ; certificat de `mail` avec SAN `mail.lab.test` et `webmail.lab.test` | Chaque maillon de la chaîne de confiance fait à la main |
| Confiance de la CA | Installée sur le poste hôte et sur `autre` | Webmail sans avertissement, TLS vérifiable entre serveurs |
| Soumission | 587 (STARTTLS) et 465 (TLS implicite) ; IMAP 143 fermé | 465 recommandé par la RFC 8314 ; les deux sont étudiés |
| Anti-spam et DKIM | Rspamd 4.2.3 du dépôt officiel + Redis local | Un seul outil pour filtrer, signer et vérifier ; version plus récente que celle d'Ubuntu |
| DKIM | Sélecteur `2026a`, signature par Rspamd sur `mail` | Sélecteur daté : rotation des clés sans conflit |
| SPF et DMARC | `v=spf1 mx -all` ; DMARC `p=none` puis `p=reject` pour `lab.test` | Observer avant d'appliquer, comme en production |
| Réseau interne Rspamd | `local_addrs = 127.0.0.0/8` | Sinon `autre`, sur le même réseau privé, serait jugé interne et non vérifié |
| Webmail | Roundcube 1.6.6, paquet Ubuntu, base SQLite | Mises à jour par `apt`, ManageSieve intégré, simple à automatiser |
| Anti-force-brute | Fail2ban, action ufw, 5 échecs en 10 min → 10 min de blocage | Blocage au pare-feu ; durée courte pour ne pas gêner les tests |
| Journalisation | rsyslog pour `/var/log/mail.log`, plus journald | Fichier attendu par Fail2ban et par les outils de diagnostic |
| Automatisation | Ansible depuis une VM de contrôle dédiée, après la phase manuelle | Comprendre d'abord, automatiser ensuite ; poste Windows non utilisé comme contrôleur |

## 7. Exigences fonctionnelles

Les sept exigences fonctionnelles sont satisfaites ; les preuves sont dans le dossier `tests/` du dépôt.

| ID | Exigence | Priorité | Statut | Preuve |
| --- | --- | --- | --- | --- |
| EF1 | Un utilisateur reçoit un message dans sa boîte Maildir, livré par LMTP | Obligatoire | Satisfaite | `tests/etape-06.md` |
| EF2 | Un utilisateur authentifié envoie un message par les ports 587 (STARTTLS) et 465 (TLS implicite) | Obligatoire | Satisfaite | `tests/etape-07.md` |
| EF3 | Un utilisateur consulte ses messages en IMAP chiffré (993), en ligne de commande et dans un client graphique | Obligatoire | Satisfaite | `tests/etape-07.md` |
| EF4 | Un utilisateur lit, envoie, supprime et classe ses messages dans Roundcube en HTTPS, et y gère un filtre Sieve | Obligatoire | Satisfaite | `tests/etape-12.md` |
| EF5 | Les messages sortants de `lab.test` sont signés DKIM ; SPF, DKIM et DMARC sont publiés et vérifiés par Rspamd sur `autre` | Obligatoire | Satisfaite | `tests/etape-10.md` |
| EF6 | `mbsuser` et `alice` échangent des messages, et chacun échange avec `test@autre.test` | Obligatoire | Satisfaite | `tests/etape-06.md`, `tests/etape-08.md` |
| EF7 | L'administrateur crée un utilisateur virtuel, change son mot de passe et le supprime avec `mailuser.sh` | Obligatoire | Satisfaite | `tests/etape-06.md` |

## 8. Exigences de sécurité

Les onze exigences de sécurité sont mises en œuvre et vérifiées ; deux contrôles complémentaires restent à faire (ES4 par `nmap`, ES2 par `testssl.sh`, voir section 10).

| ID | Exigence | Mise en œuvre | Statut |
| --- | --- | --- | --- |
| ES1 | Aucun relais ouvert | `mynetworks = 127.0.0.0/8`, `reject_unauth_destination` ; 465/587 : `permit_sasl_authenticated, reject` | Vérifiée : `554 5.7.1 Relay access denied` depuis `autre` |
| ES2 | TLS obligatoire pour les utilisateurs, opportuniste entre serveurs | `smtpd_tls_auth_only = yes`, 587 en `encrypt`, 465 implicite, 143 fermé, HTTP redirigé ; port 25 en `may` | Vérifiée : TLS 1.3 sur 465, 587, 993 ; ESMTPS entre serveurs |
| ES3 | Maildir protégés | Dossiers `700`, fichiers `600`, propriétaire `vmail` | Vérifiée : `700 vmail` |
| ES4 | Pare-feu minimal | ufw : tout refusé en entrée ; ports de la matrice ouverts sur `enp0s8` depuis `192.168.56.0/24` | Vérifiée par `ufw status` et `Test-NetConnection` |
| ES5 | Mots de passe hachés, aucun secret dans le dépôt | BLF-CRYPT ; secrets masqués ou exclus ; contrôle `git grep` avant publication | Vérifiée |
| ES6 | Administration non exposée | Interface Rspamd sur `127.0.0.1:11334`, accès par tunnel SSH ; répertoire d'installation de Roundcube non servi | Vérifiée |
| ES7 | Pas de compte système pour les boîtes | Comptes de test créés en `nologin`, puis supprimés après la migration | Vérifiée : `getent passwd` vide |
| ES8 | Aucun webmail abandonné | Roundcube du dépôt Ubuntu ; RainLoop exclu | Vérifiée |
| ES9 | Anti-force-brute | Fail2ban : prisons `sshd`, `postfix-sasl`, `dovecot`, `roundcube-auth` ; tests depuis `autre`, hôte non exempté | Vérifiée : `192.168.56.20` banni puis libéré |
| ES10 | Horloge synchronisée | `systemd-timesyncd` | Vérifiée : `System clock synchronized: yes` |
| ES11 | Services internes en local | Redis, ManageSieve (4190), Rspamd (11332-11334) sur `127.0.0.1` | Vérifiée par `ss -ltnp` |

**Matrice des ports de la VM `mail`**

| Port | Service | Ouvert à | Remarque |
| --- | --- | --- | --- |
| 22/tcp | SSH | Réseau privé hôte | Clé uniquement, `root` interdit |
| 25/tcp | SMTP entre serveurs | Réseau privé hôte | Réception depuis `autre.test` |
| 53/tcp+udp | DNS (dnsmasq) | Réseau privé hôte | Résolveur de `autre` |
| 80/tcp | HTTP | Réseau privé hôte | Redirection 301 vers HTTPS |
| 443/tcp | HTTPS | Réseau privé hôte | Roundcube |
| 465/tcp | Soumission TLS implicite | Réseau privé hôte | Authentification obligatoire |
| 587/tcp | Soumission STARTTLS | Réseau privé hôte | Authentification obligatoire |
| 993/tcp | IMAPS | Réseau privé hôte | 143 fermé |
| 4190/tcp | ManageSieve | Non ouvert | Écoute locale, utilisé par Roundcube |
| 6379/tcp | Redis | Non ouvert | Écoute locale |
| 11332-11334/tcp | Rspamd (milter, contrôleur) | Non ouvert | Interface par tunnel SSH |

## 9. Plan de réalisation et avancement

Douze étapes sur treize sont terminées entre le 27 et le 30 octobre 2026 ; reste l'automatisation Ansible.

| Étape | Contenu | Livrable | Statut |
| --- | --- | --- | --- |
| 1 | Chemin d'un e-mail, rôle de chaque composant | Schéma d'architecture et glossaire | Terminée |
| 2 | VM `mail` : installation, IP fixe, SSH par clé, horloge, journalisation, ufw | VM prête, instantané de base | Terminée |
| 3 | DNS local dnsmasq : zones `lab.test` et `autre.test` | Résolution A, MX, PTR depuis la VM et l'hôte | Terminée |
| 4 | Postfix seul, comptes système, file d'attente, journaux | Message local reçu, `main.cf` compris | Terminée |
| 5 | Dovecot et Maildir avec comptes système | Session IMAP validée | Terminée |
| 6 | Utilisateurs virtuels : `vmail`, fichier `users`, LMTP, `mailuser.sh` | Migration documentée, anciens comptes supprimés | Terminée |
| 7 | CA OpenSSL, TLS, authentification SMTP sur 587, 465, 993 | Soumission sécurisée, non-relais prouvé | Terminée |
| 8 | VM `autre`, échanges sur le port 25 | Aller-retour tracé dans les deux journaux | Terminée |
| 9 | Rspamd et Redis sur les deux VM | GTUBE rejeté, scores lus dans l'interface | Terminée |
| 10 | DKIM, SPF, DMARC | `spf=pass dkim=pass dmarc=pass` sur `autre`, usurpation rejetée | Terminée |
| 11 | Fail2ban : prisons Postfix SASL, Dovecot, SSH | IP de `autre` bannie puis libérée | Terminée |
| 12 | Webmail : Apache, PHP-FPM, Roundcube, ManageSieve, prison Roundcube | HTTPS sans avertissement, filtre Sieve actif | Terminée |
| 13 | Ansible : un rôle par composant, `ansible-vault`, validation | Deux VM reconstruites, second passage `changed=0` | À réaliser |

**Méthode appliquée**

- Configuration à la main, paramètre par paramètre, sans copier de configuration complète.
- Instantané avant chaque étape, VM éteinte.
- Erreurs provoquées volontairement pour apprendre à lire les journaux.
- Pour chaque étape, une page de documentation (objectif, réalisation, problèmes rencontrés, enseignements) et une fiche de preuves avec captures.

## 10. Recette

Onze critères d'acceptation sur quatorze sont validés avec preuve ; restent l'audit TLS, le balayage des ports et la reconstruction Ansible.

| Critère | Commande de preuve | Résultat attendu | Résultat |
| --- | --- | --- | --- |
| Échange interne (EF6) | `swaks` de `mbsuser` vers `alice` | Message livré dans le Maildir du destinataire | Validé |
| Échange entre domaines (EF6) | `swaks` de `lab.test` vers `autre.test`, puis inverse | `status=sent` ; en-têtes ESMTPSA puis ESMTPS | Validé |
| IMAP chiffré (EF3) | `openssl s_client -connect mail.lab.test:993`, Thunderbird | `Verification: OK`, TLS 1.3 | Validé |
| Soumission authentifiée (EF2) | `swaks --auth` sur 587 (`--tls`) et 465 (`--tlsc`) | `235` puis `250 queued` | Validé |
| Non-relais (ES1) | `swaks` sans authentification depuis `autre`, vers un domaine externe | `554 5.7.1 Relay access denied` | Validé |
| DKIM, SPF, DMARC (EF5) | En-têtes du message reçu sur `autre` | `dkim=pass`, `spf=pass`, `dmarc=pass` | Validé |
| Usurpation (EF5) | Expéditeur `@lab.test` envoyé depuis `autre` | Message rejeté (`554 5.7.1`) | Validé |
| Anti-spam | Message GTUBE depuis `autre` | `554 5.7.1 Gtube pattern` | Validé |
| Webmail (EF4) | `https://webmail.lab.test` depuis l'hôte | Aucun avertissement ; filtre vers *Projets* et spam vers *Pourriels* | Validé |
| Permissions (ES3) | `stat` du Maildir | `700 vmail` | Validé |
| Fail2ban (ES9) | Échecs d'authentification répétés depuis `autre` | IP bannie, règle `REJECT` dans ufw | Validé |
| Qualité TLS (ES2) | `testssl.sh` sur 443, 465, 587, 993 | Ni SSLv3, ni TLS 1.0/1.1, aucune vulnérabilité signalée | À réaliser |
| Ports (ES4) | `nmap` depuis l'hôte | Seuls les ports de la matrice ouverts | À réaliser |
| Reproductibilité (PF2) | Playbook Ansible sur deux VM vierges, puis relance | Tous les tests au vert ; `changed=0` au second passage | À réaliser (étape 13) |

Les fiches `tests/etape-NN.md` détaillent chaque contrôle avec sa capture.

## 11. Livrables et gestion des secrets

Le livrable est le dépôt GitHub public `mail-server-lab` ; il ne contient aucun secret, ce que contrôle une recherche `git grep` avant chaque publication.

| Élément du dépôt | Contenu | Statut |
| --- | --- | --- |
| `README.md` | Objectif, architecture, résultats avec liens vers les preuves, limites | Livré |
| `SECURITY.md` | Exigences de sécurité, secrets, compromis assumés, limites | Livré |
| `docs/` | Cahier des charges, architecture, une page par étape, captures | Livré (étapes 2 à 12) |
| `configs/` | Configurations réelles des deux VM, secrets masqués | Livré |
| `scripts/` | `mailuser.sh`, `collect-configs.sh` | Livré |
| `tests/` | Une fiche de preuves par étape | Livré (étapes 2 à 12) |
| `ansible/` | Rôles, inventaire, playbooks, coffre chiffré | À réaliser (étape 13) |

**Secrets jamais publiés**

| Secret | Emplacement | Traitement |
| --- | --- | --- |
| Clé privée de la CA | Poste hôte uniquement | Exclue par `.gitignore` |
| Clés privées TLS des serveurs | `/etc/ssl/private/` (`600 root`) | Jamais collectées |
| Clé privée DKIM | `/var/lib/rspamd/dkim/` (`440 _rspamd`) | Jamais collectée ; seule la clé publique (TXT) est publiée |
| Hashs des boîtes | `/etc/dovecot/users` (`640 root:dovecot`) | Remplacé par `users.example`, hashs masqués |
| Hash de l'interface Rspamd | `local.d/worker-controller.inc` | Remplacé par `<REDACTED>` |
| `des_key` de Roundcube | `/etc/roundcube/config.inc.php` | Remplacée par `<REDACTED>` |
| Secrets Ansible (étape 13) | Fichier de variables du contrôleur | Chiffrés par `ansible-vault` ; mot de passe du coffre jamais versionné |

Le `.gitignore` exclut clés, certificats privés, clés SSH, archives et fichier `users`. Les captures publiées sont relues : aucun mot de passe saisi ni donnée personnelle visible.

## 12. Limites par rapport à la production

Ce projet est un laboratoire et n'est jamais présenté comme un déploiement de production ; la seconde VM réduit l'écart sur l'authentification des messages, pas sur Internet.

| Élément | En laboratoire | En production | Ce qui n'est pas appris |
| --- | --- | --- | --- |
| Port 25 et Internet | Trafic entre deux VM locales | Port 25 souvent bloqué ou restreint par les fournisseurs | Faire lever ce blocage ou passer par un relais |
| Reverse DNS (PTR) | Servi par dnsmasq | Configuré chez l'hébergeur de l'IP | Effet réel du PTR sur l'acceptation des messages |
| Délivrabilité | Vérifiée entre `lab.test` et `autre.test` | Dépend de Gmail, Outlook et des autres | Résultats réels chez les grands fournisseurs |
| Réputation d'IP | Sans objet | Listes noires, méfiance envers une IP neuve | Gestion de la réputation |
| DNS public | dnsmasq, zones fictives | Propagation, TTL, erreurs de MX | Comportement réel du DNS |
| Rapports DMARC | Adresse `rua` non exploitée | Rapports agrégés quotidiens | Lecture et exploitation des rapports |
| Certificats TLS | CA locale OpenSSL | Let's Encrypt, renouvellement automatique | Renouvellement en conditions réelles |
| Attaques | Simulées depuis `autre` | Automatisées dès les premières heures | Réglage de Fail2ban sur du trafic réel |
| Antivirus | Exclu (mémoire) | ClamAV ou équivalent | Intégration et coût mémoire |
| Exploitation | VM éteintes hors des séances | Disponibilité continue | Supervision, alertes, mises à jour à chaud |
| Sauvegarde | Instantanés VirtualBox | Sauvegardes externalisées, restaurations testées | Stratégie de reprise après incident |
| Volume | Trois boîtes de test | Nombreux utilisateurs, pics de trafic | Dimensionnement, quotas |
| Haute disponibilité | Un serveur par domaine | MX secondaire, redondance | Architecture redondante |

## 13. Risques, mesures et constats

Aucun risque n'a bloqué le projet ; trois se sont produits et ont été traités par la mesure prévue ou un correctif documenté.

| Risque | Probabilité | Impact | Mesure | Constat (étapes 1 à 12) |
| --- | --- | --- | --- | --- |
| Mémoire insuffisante sur l'hôte de 8 Go | Moyenne | Élevé | 4,5 Go pour les VM, ClamAV exclu, `autre` démarrée à partir de l'étape 8 | Non survenu |
| VirtualBox ralenti par Hyper-V ou WSL2 | Moyenne | Moyen | Vérification à l'étape 2 | Non survenu |
| Erreur de configuration rendant une VM inutilisable | Élevée | Moyen | Instantané avant chaque étape | Survenu (route réseau, `mail_location`) ; corrigé sans retour arrière |
| Clone héritant d'un état mémoire | Faible | Faible | Instantanés pris VM éteinte | Survenu à l'étape 8 ; état sauvegardé oublié, règle ajoutée |
| Conflit sur le port 53 entre `systemd-resolved` et dnsmasq | Élevée | Moyen | Désactivation de `systemd-resolved`, `resolv.conf` fixe | Prévenu |
| Test de non-relais faussé | Moyenne | Élevé | `mynetworks` limité à `127.0.0.0/8`, test depuis `autre` | Prévenu |
| Vérification SPF/DKIM illusoire | Moyenne | Élevé | Vérification sur `autre` ; `local_addrs` restreint | Prévenu |
| Test anti-spam masqué par un bon score d'authentification | Moyenne | Faible | Seuil temporaire abaissé pendant le test | Survenu à l'étape 12 ; seuil ajusté puis rétabli |
| Bannissement de l'hôte par Fail2ban | Moyenne | Moyen | Tests depuis `autre`, commande de libération documentée | Non survenu |
| Fuite de secrets dans GitHub | Moyenne | Élevé | `.gitignore`, collecte avec masquage, contrôle `git grep`, relecture des captures | Prévenu ; un mot de passe visible sur une capture a été masqué avant publication |
| Copie aveugle de tutoriels | Moyenne | Moyen | Paramètres ajoutés un à un et expliqués | Prévenu |
| Surestimation de la portée du projet | Moyenne | Moyen | Section « Limites » reprise dans le README | Prévenu |

## 14. Évolutions prévues

L'automatisation Ansible est la prochaine étape ; les autres évolutions sont classées par ordre de priorité.

1. **Automatisation Ansible (étape 13)** : VM de contrôle `ctrl` ; rôles `base`, `dns`, `tls`, `postfix`, `dovecot`, `rspamd`, `webmail`, `fail2ban` ; secrets chiffrés par `ansible-vault` ; playbook de validation reprenant la recette ; test d'idempotence.
2. **Contrôles complémentaires** : audit `testssl.sh` et balayage `nmap` (section 10).
3. **Utilisateurs en base SQL** : migration du fichier `users` vers MariaDB ou PostgreSQL, avec une interface d'administration.
4. **Validation en conditions réelles** : exécution du playbook sur un VPS vierge avec un domaine dédié, pour couvrir port 25, PTR, délivrabilité et Let's Encrypt.
5. **Améliorations** : ClamAV sur un hôte mieux doté, quotas, sauvegardes `doveadm backup` avec restauration testée, supervision, IPv6, MX secondaire.

## Annexe A : glossaire

| Terme | Définition |
| --- | --- |
| MUA | Client de messagerie (Thunderbird, Roundcube) |
| MSA | Service qui reçoit les messages des utilisateurs authentifiés (ports 465 et 587) |
| MTA | Serveur qui achemine les messages entre domaines (Postfix, port 25) |
| MDA | Service qui dépose le message dans la boîte (Dovecot) |
| LMTP | Protocole de remise locale entre Postfix et Dovecot |
| Maildir | Format de stockage : un fichier par message, dossiers `new`, `cur`, `tmp` |
| SASL | Cadre d'authentification ; Dovecot authentifie les utilisateurs pour Postfix |
| STARTTLS | Passage au chiffrement sur une connexion déjà ouverte (port 587) |
| SPF | Enregistrement DNS listant les serveurs autorisés à envoyer pour un domaine |
| DKIM | Signature cryptographique des messages, clé publique publiée dans le DNS |
| DMARC | Politique du domaine en cas d'échec SPF ou DKIM (`none`, `quarantine`, `reject`) |
| Milter | Interface par laquelle Postfix confie chaque message à un filtre (Rspamd) |
| GTUBE | Message de test reconnu comme spam par tous les filtres |
| Sieve | Langage de filtres côté serveur ; ManageSieve permet de les gérer à distance |
| PTR | Enregistrement DNS inverse : de l'adresse IP vers le nom |
| Idempotence | Propriété d'un playbook qui ne change plus rien quand il est relancé |
