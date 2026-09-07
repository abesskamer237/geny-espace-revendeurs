#!/usr/bin/env bash
set -euo pipefail
cd "${ENSPY_APP_DIR:-/opt/enspy}"
DOMAIN="${ENSPY_DOMAIN:-enspy.pagnol.xyz}"

echo "=== SERVICES ==="
docker compose ps
echo
echo "=== NETWORK ==="
docker network inspect enspy_network --format '{{range .Containers}}{{.Name}} -> {{.IPv4Address}}{{"\\n"}}{{end}}' 2>/dev/null || true
echo
echo "=== PORTS ==="
ss -ltnp | grep -E ':(80|443|8080)\\s' || true
echo
echo "=== API DIRECT ==="
curl --noproxy '*' -i --max-time 5 http://127.0.0.1:8080/api/healthz || true
echo
echo "=== API VIA NGINX HTTP ==="
curl --noproxy '*' -i --max-time 5 http://127.0.0.1/api/healthz || true
echo
echo "=== API VIA NGINX HTTPS ==="
curl --noproxy '*' -ki --max-time 8 --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/api/healthz" || true
echo
echo "=== NGINX CONFIG ==="
docker compose exec -T nginx nginx -t || true
echo
echo "=== CERTIFICATE ==="
ls -la "certbot/conf/live/$DOMAIN/" 2>/dev/null || true
echo
echo "=== NGINX LOGS ==="
docker compose logs --tail=100 nginx
echo
echo "=== API LOGS ==="
docker compose logs --tail=100 api
