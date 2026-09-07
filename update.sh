#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${ENSPY_DIR:-/opt/enspy}"
DOMAIN="${ENSPY_DOMAIN:-enspy.pagnol.xyz}"
cd "$APP_DIR"

echo "[ENSPY] Mise à jour du dépôt"
git fetch --all --prune
git pull --ff-only

# Never let a tracked HTTP bootstrap nginx.conf downgrade a live HTTPS server.
if [[ -s "certbot/conf/live/$DOMAIN/fullchain.pem" && -s "certbot/conf/live/$DOMAIN/privkey.pem" ]]; then
  echo "[ENSPY] Certificat présent : conservation de la configuration HTTPS"
  sed "s|__ENSPY_DOMAIN__|$DOMAIN|g" nginx.https.conf > nginx.conf
else
  echo "[ENSPY] Aucun certificat local : configuration HTTP bootstrap"
  sed "s|__ENSPY_DOMAIN__|$DOMAIN|g" nginx.http.conf > nginx.conf
fi

docker compose up -d --build

docker compose exec -T nginx nginx -t
if [[ -s "certbot/conf/live/$DOMAIN/fullchain.pem" && -s "certbot/conf/live/$DOMAIN/privkey.pem" ]]; then
  docker compose exec -T nginx nginx -s reload >/dev/null 2>&1 || true
  curl --noproxy '*' -fsS --max-time 8 --resolve "$DOMAIN:443:127.0.0.1"     "https://$DOMAIN/api/healthz" >/dev/null
fi

docker compose ps
echo "ENSPY Server mis à jour."
