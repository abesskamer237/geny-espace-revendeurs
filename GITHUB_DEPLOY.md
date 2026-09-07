# ENSPY Server — Déploiement VPS

## 1. Préparer GitHub

Créer le dépôt GitHub et pousser **le contenu de `ENSPY-Server/` à la racine du dépôt** (afin que `install.sh` soit directement à la racine).

Ne jamais pousser :
- `.env`
- mots de passe
- tokens
- certificats privés
- clés privées

## 2. Installation en une commande

Sur un VPS Ubuntu/Debian :

```bash
curl -fsSL https://raw.githubusercontent.com/COMPTE/ENSPY-Server/main/install.sh | sudo env ENSPY_REPO_URL=https://github.com/COMPTE/ENSPY-Server.git bash
```

Remplacer `COMPTE/ENSPY-Server` par le dépôt réel.

> Pour éviter toute ambiguïté dans un copier-coller, il est également recommandé de cloner le dépôt puis d'exécuter `sudo ./install.sh` avec `ENSPY_REPO_URL` défini.

## 3. Mise à jour

```bash
cd /opt/enspy
./update.sh
```

## 4. Backup PostgreSQL

```bash
cd /opt/enspy
./backup.sh
```

Le backup est placé dans `/opt/enspy-backups`.

## 5. Vérifications

```bash
docker compose ps
docker compose logs --tail=100 api
```

Si le serveur utilise le domaine configuré dans `.env`, vérifier ensuite :

`https://enspy.pagnol.xyz/health`

## Sécurité

L'installation conserve les valeurs déjà présentes dans `.env` et ne génère automatiquement que les secrets absents. Avant une première mise en production, renseigner impérativement le vrai mot de passe PostgreSQL et les paramètres propres au domaine.


## URL exacte pour le dépôt ENSPY

Le dépôt attendu par défaut par `install.sh` est :

```text
https://github.com/abesskamer237/ENSPY-Server.git
```

La commande d'installation publique est donc :

```bash
curl -fsSL https://raw.githubusercontent.com/abesskamer237/ENSPY-Server/main/install.sh | sudo bash
```

Pour un autre dépôt :

```bash
curl -fsSL https://raw.githubusercontent.com/COMPTE/DEPOT/main/install.sh | sudo env ENSPY_REPO_URL=https://github.com/COMPTE/DEPOT.git bash
```


## Dépôt GitHub officiel ENSPY

Dépôt : `https://github.com/abesskamer237/ENSPY-Server.git`

Installation directe :

```bash
curl -fsSL https://raw.githubusercontent.com/abesskamer237/ENSPY-Server/main/install.sh | sudo bash
```
