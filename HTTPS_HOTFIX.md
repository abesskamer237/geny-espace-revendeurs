# HTTPS HOTFIX — ENSPY Server v2.3.0

## Problème corrigé
Une installation pouvait obtenir correctement le certificat Let's Encrypt puis laisser Nginx sur la configuration HTTP bootstrap, ce qui produisait un Cloudflare 521 sur HTTPS.

## Corrections
- activation HTTPS explicite après émission du certificat ;
- vérification des fichiers `fullchain.pem` et `privkey.pem` ;
- validation `nginx -t` avant de considérer HTTPS opérationnel ;
- test local TLS avec `curl --resolve` sans proxy ;
- diagnostic Nginx automatique en cas d'échec ;
- `update.sh` conserve HTTPS lorsqu'un certificat existe ;
- aucun volume PostgreSQL ou uploads n'est supprimé par ces corrections.

## Réparation d'un VPS déjà installé
Sur le VPS déjà opérationnel, la configuration HTTPS peut être régénérée sans toucher aux données :

```bash
cd /opt/enspy
sed 's|__ENSPY_DOMAIN__|enspy.pagnol.xyz|g' nginx.https.conf > nginx.conf
docker compose up -d --force-recreate nginx
docker exec enspy-nginx-1 nginx -t
curl --noproxy '*' -k --resolve enspy.pagnol.xyz:443:127.0.0.1 https://enspy.pagnol.xyz/api/healthz
```

Puis vérifier publiquement :

```bash
curl -fsS https://enspy.pagnol.xyz/api/healthz
```

Le résultat attendu est `{"status":"ok"}`.
