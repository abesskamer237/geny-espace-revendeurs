#!/usr/bin/env bash
set -Eeuo pipefail
DOMAIN="${ENSPY_DOMAIN:-enspy.pagnol.xyz}"
cd /opt/enspy
[[ -f "certbot/conf/live/$DOMAIN/fullchain.pem" ]] || exit 0
docker compose --profile certbot run --rm certbot renew --quiet
docker exec enspy-nginx-1 nginx -t >/dev/null
docker exec enspy-nginx-1 nginx -s reload >/dev/null 2>&1 || true
