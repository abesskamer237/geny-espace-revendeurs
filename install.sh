#!/usr/bin/env bash
set -Eeuo pipefail

# ENSPY Platform v2.3.0 — production one-command VPS installer
# WARNING: by design this installer takes ownership of public HTTP/HTTPS ports.
# It stops/disables common host web servers and removes Docker containers that
# publish 80/443. It never deletes Docker volumes used by ENSPY.
REPO_URL="${ENSPY_REPO_URL:-https://github.com/abesskamer237/ENSPY-Server.git}"
BRANCH="${ENSPY_REPO_BRANCH:-main}"
APP_DIR="${ENSPY_APP_DIR:-/opt/enspy}"
ENSPY_DOMAIN="${ENSPY_DOMAIN:-enspy.pagnol.xyz}"
FORCE_PORTS="${ENSPY_FORCE_PORTS:-1}"
CERTBOT_IMAGE="${ENSPY_CERTBOT_IMAGE:-certbot/certbot:v5.7.0}"
CERT_NAME="$ENSPY_DOMAIN"

log(){ printf '\n\033[1;36m[ENSPY]\033[0m %s\n' "$*"; }
warn(){ printf '\n\033[1;33m[ENSPY][ATTENTION]\033[0m %s\n' "$*" >&2; }
fail(){ printf '\n\033[1;31m[ENSPY][ERREUR]\033[0m %s\n' "$*" >&2; exit 1; }
trap 'rc=$?; if [[ $rc -ne 0 ]]; then echo; echo "[ENSPY] Diagnostics:"; (cd "$APP_DIR" 2>/dev/null && docker compose ps && docker compose logs --tail=100 api nginx db-init 2>/dev/null) || true; fi; exit $rc' ERR

[[ $EUID -eq 0 ]] || fail "Lancez cette commande avec sudo/root."

export DEBIAN_FRONTEND=noninteractive

if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) ;;
    *) fail "Distribution non prise en charge automatiquement: ${ID:-inconnue}. Utilisez Debian ou Ubuntu." ;;
  esac
fi

log "Installation des prérequis"
apt-get update -y >/dev/null
apt-get install -y ca-certificates curl git openssl psmisc iproute2 >/dev/null

if ! command -v docker >/dev/null 2>&1; then
  log "Installation de Docker"
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 est requis."

# ---------- Take ownership of ports 80/443 ----------
free_ports() {
  [[ "$FORCE_PORTS" == "1" ]] || { warn "ENSPY_FORCE_PORTS=$FORCE_PORTS : les services concurrents ne seront pas arrêtés."; return; }

  log "Libération forcée des ports 80/443"

  # Common host web servers. Stop + disable, but do not uninstall or delete configs.
  for svc in nginx apache2 httpd caddy lighttpd; do
    if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
      if systemctl is-active --quiet "$svc" 2>/dev/null || systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        log "Arrêt/désactivation de $svc"
        systemctl stop "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        systemctl mask "$svc" 2>/dev/null || true
      fi
    fi
  done

  # Any Docker container publishing host 80/443 is a direct conflict.
  local ids id ports name
  ids="$(docker ps -q || true)"
  for id in $ids; do
    ports="$(docker inspect -f '{{json .HostConfig.PortBindings}}' "$id" 2>/dev/null || true)"
    if echo "$ports" | grep -Eq '"80/tcp"|"443/tcp"'; then
      name="$(docker inspect -f '{{.Name}}' "$id" 2>/dev/null | sed 's#^/##' || echo "$id")"
      log "Arrêt/suppression du conteneur concurrent $name (ports 80/443)"
      docker rm -f "$id" >/dev/null 2>&1 || true
    fi
  done

  # Last resort: an unknown process holding 80/443 is terminated.
  # This is intentionally destructive because the installer is requested to
  # take ownership of the public web ports.
  if ss -ltnp | grep -Eq ':(80|443)\s'; then
    warn "Un processus inconnu occupe encore 80/443 : libération forcée."
    fuser -k 80/tcp 443/tcp >/dev/null 2>&1 || true
    sleep 2
  fi

  if ss -ltnp | grep -Eq ':(80|443)\s'; then
    ss -ltnp | grep -E ':(80|443)\s' || true
    fail "Impossible de libérer les ports 80/443."
  fi
}
free_ports

# ---------- Source ----------
if [[ -d "$APP_DIR/.git" ]]; then
  log "Mise à jour du dépôt existant"
  git -C "$APP_DIR" fetch --depth 1 origin "$BRANCH"
  git -C "$APP_DIR" checkout -q "$BRANCH"
  git -C "$APP_DIR" reset --hard "origin/$BRANCH" >/dev/null
else
  if [[ -e "$APP_DIR" && -n "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    # Existing non-git directory is moved aside rather than destroyed.
    BACKUP_DIR="${APP_DIR}.backup.$(date +%Y%m%d-%H%M%S)"
    log "$APP_DIR existe : déplacement sécurisé vers $BACKUP_DIR"
    mv "$APP_DIR" "$BACKUP_DIR"
  fi
  mkdir -p "$(dirname "$APP_DIR")"
  log "Clonage du serveur ENSPY"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"
mkdir -p certbot/www/.well-known/acme-challenge certbot/conf
chmod 755 certbot certbot/www certbot/www/.well-known certbot/www/.well-known/acme-challenge certbot/conf

# ---------- Secrets ----------
if [[ ! -f .env ]]; then
  log "Création sécurisée du .env"
  cp .env.example .env
  chmod 600 .env
else
  log ".env existant conservé"
  chmod 600 .env
fi

# Generate missing/placeholder secrets, but preserve real existing secrets.
ensure_secret() {
  local key="$1" bytes="$2"
  local current=""
  current="$(grep -E "^${key}=" .env | tail -1 | cut -d= -f2- || true)"
  if [[ -z "$current" || "$current" =~ ^remplacez_ || "$current" =~ ^CHANGE_ME || "$current" =~ ^changeme$ ]]; then
    current="$(openssl rand -hex "$bytes")"
    if grep -qE "^${key}=" .env; then
      sed -i "s|^${key}=.*|${key}=${current}|" .env
    else
      printf '%s=%s\n' "$key" "$current" >> .env
    fi
    chmod 600 .env
    log "Secret ${key} généré automatiquement."
  fi
}

ensure_secret POSTGRES_PASSWORD 32
ensure_secret JWT_SECRET 48

grep -Eq '^POSTGRES_PASSWORD=.{16,}$' .env || fail "POSTGRES_PASSWORD absent ou trop court dans .env"
grep -Eq '^JWT_SECRET=.{32,}$' .env || fail "JWT_SECRET absent ou trop court dans .env"

# ---------- Secure initial administrator ----------
ADMIN_EMAIL="${ENSPY_ADMIN_EMAIL:-admin@enspy.cm}"
if ! grep -q '^ENSPY_ADMIN_EMAIL=' .env; then
  printf 'ENSPY_ADMIN_EMAIL=%s\n' "$ADMIN_EMAIL" >> .env
else
  ADMIN_EMAIL="$(grep '^ENSPY_ADMIN_EMAIL=' .env | tail -1 | cut -d= -f2-)"
fi

ADMIN_INITIAL_PASSWORD="$(grep '^ENSPY_ADMIN_INITIAL_PASSWORD=' .env | tail -1 | cut -d= -f2- || true)"
if [[ -z "$ADMIN_INITIAL_PASSWORD" ]]; then
  ADMIN_INITIAL_PASSWORD="$(openssl rand -hex 24)"
  printf 'ENSPY_ADMIN_INITIAL_PASSWORD=%s\n' "$ADMIN_INITIAL_PASSWORD" >> .env
  chmod 600 .env
  log "Un mot de passe administrateur initial unique a été généré."
  warn "Conservez précieusement le mot de passe affiché à la fin de l'installation."
fi
[[ "$ADMIN_INITIAL_PASSWORD" =~ ^[A-Za-z0-9_-]{20,}$ ]] || fail "ENSPY_ADMIN_INITIAL_PASSWORD invalide ou trop court."

# ---------- Production domain ----------
DOMAIN="$ENSPY_DOMAIN"
[[ "$DOMAIN" == "enspy.pagnol.xyz" || "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || fail "ENSPY_DOMAIN invalide: $DOMAIN"

PUBLIC_IP="$(curl -4fsS --max-time 10 https://api.ipify.org || true)"
if ! [[ "$PUBLIC_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  PUBLIC_IP="$(curl -4fsS --max-time 10 https://ifconfig.me/ip || true)"
fi
[[ "$PUBLIC_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || fail "Impossible de déterminer l'IPv4 publique du VPS."

DOMAIN_IPS="$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//' || true)"
DOMAIN_IP="$(printf '%s\n' "$DOMAIN_IPS" | awk '{print $1}')"
if [[ -z "$DOMAIN_IPS" ]]; then
  warn "Le DNS de $DOMAIN ne se résout pas encore."
  warn "L'installation continuera et le certificat sera demandé si le challenge ACME devient accessible."
elif ! printf '%s\n' "$DOMAIN_IPS" | tr ' ' '\n' | grep -Fxq "$PUBLIC_IP"; then
  warn "Le DNS de $DOMAIN ne renvoie pas directement l'IP du VPS ($PUBLIC_IP)."
  warn "Cela peut être normal avec Cloudflare Proxy ou un autre reverse-proxy."
  warn "La validation ACME fera foi ; aucune comparaison d'IP stricte ne bloquera le certificat."
fi

if grep -q '^PUBLIC_API_URL=' .env; then
  sed -i "s|^PUBLIC_API_URL=.*|PUBLIC_API_URL=https://$DOMAIN/api/|" .env
else
  printf '\nPUBLIC_API_URL=https://%s/api/\n' "$DOMAIN" >> .env
fi

# ---------- Docker network ----------
docker network inspect enspy_network >/dev/null 2>&1 || docker network create --driver bridge enspy_network >/dev/null

# ---------- Render Nginx for the configured domain ----------
render_nginx_http() {
  sed "s|__ENSPY_DOMAIN__|$DOMAIN|g" nginx.http.conf > nginx.conf
}
render_nginx_https() {
  sed "s|__ENSPY_DOMAIN__|$DOMAIN|g" nginx.https.conf > nginx.conf
}

log "Nettoyage des anciens conteneurs ENSPY (volumes conservés)"
docker compose down --remove-orphans >/dev/null 2>&1 || true

log "Téléchargement des images"
docker compose pull postgres nginx
docker pull "$CERTBOT_IMAGE"

log "Construction de l'API"
docker compose build --pull api

# ---------- PostgreSQL ----------
log "Démarrage PostgreSQL"
docker compose up -d postgres

log "Attente PostgreSQL"
for i in $(seq 1 60); do
  if [[ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q postgres)" 2>/dev/null || true)" == "healthy" ]]; then break; fi
  sleep 2
  [[ "$i" -lt 60 ]] || fail "PostgreSQL n'est pas devenu healthy."
done

# ---------- Migrations ----------
log "Exécution des migrations"
docker compose up -d db-init
DB_INIT_ID="$(docker compose ps -aq db-init)"
for i in $(seq 1 90); do
  STATUS="$(docker inspect -f '{{.State.Status}}' "$DB_INIT_ID" 2>/dev/null || true)"
  [[ "$STATUS" == "exited" ]] && break
  sleep 1
  [[ "$i" -lt 90 ]] || fail "db-init n'a pas terminé."
done
[[ "$(docker inspect -f '{{.State.ExitCode}}' "$DB_INIT_ID")" == "0" ]] || {
  docker compose logs --tail=200 db-init
  fail "Les migrations PostgreSQL ont échoué."
}

# ---------- API ----------
log "Démarrage de l'API"
docker compose up -d --force-recreate api

log "Attente de l'API healthy"
for i in $(seq 1 60); do
  if [[ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q api)" 2>/dev/null || true)" == "healthy" ]]; then break; fi
  sleep 2
  [[ "$i" -lt 60 ]] || fail "L'API n'est pas devenue healthy."
done

curl -fsS --max-time 5 http://127.0.0.1:8080/api/healthz | grep -q '"status"' || fail "L'API ne répond pas sur 127.0.0.1:8080."

# ---------- HTTP Nginx bootstrap ----------
log "Configuration HTTP temporaire pour validation ACME"
render_nginx_http
docker compose up -d --force-recreate nginx

log "Vérification Nginx + API"
for i in $(seq 1 60); do
  if curl -fsS --max-time 5 http://127.0.0.1/api/healthz | grep -q '"status"'; then break; fi
  sleep 2
  [[ "$i" -lt 60 ]] || fail "Nginx ne relaie pas /api/healthz."
done

# ---------- Firewall ----------
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  log "Ouverture UFW des ports HTTP/HTTPS"
  ufw allow 80/tcp >/dev/null || true
  ufw allow 443/tcp >/dev/null || true
fi

# ---------- Domain TLS certificate ----------
CERT_LIVE="$APP_DIR/certbot/conf/live/$CERT_NAME"
CERT_OK=0

# Verify the ACME webroot is readable through the actual HTTP server before asking CA.
ACME_TEST="enspy-acme-$(date +%s)-$$"
printf '%s\n' "$ACME_TEST" > "$APP_DIR/certbot/www/.well-known/acme-challenge/$ACME_TEST"
chmod 644 "$APP_DIR/certbot/www/.well-known/acme-challenge/$ACME_TEST"
if curl -fsS --max-time 8 --resolve "$DOMAIN:80:127.0.0.1" \
    "http://$DOMAIN/.well-known/acme-challenge/$ACME_TEST" | grep -q "$ACME_TEST"; then
  log "Validation ACME locale OK"
else
  rm -f "$APP_DIR/certbot/www/.well-known/acme-challenge/$ACME_TEST"
  fail "Nginx ne sert pas correctement le répertoire ACME. Vérifiez les permissions et le montage /var/www/certbot."
fi
rm -f "$APP_DIR/certbot/www/.well-known/acme-challenge/$ACME_TEST"

if [[ -s "$CERT_LIVE/fullchain.pem" && -s "$CERT_LIVE/privkey.pem" ]]; then
  CERT_OK=1
  log "Certificat Let's Encrypt existant pour $DOMAIN : conservation"
else
  log "Demande du certificat Let's Encrypt pour $DOMAIN"

  set +e
  docker compose --profile certbot run --rm certbot \
    certonly --webroot -w /var/www/certbot \
    --cert-name "$CERT_NAME" \
    --non-interactive --agree-tos \
    --register-unsafely-without-email \
    --no-eff-email \
    -d "$DOMAIN"
  CERT_RC=$?
  set -e

  if [[ "$CERT_RC" -eq 0 && -s "$CERT_LIVE/fullchain.pem" && -s "$CERT_LIVE/privkey.pem" ]]; then
    CERT_OK=1
    chmod 755 "$APP_DIR/certbot/conf" "$CERT_LIVE"
    chmod 644 "$CERT_LIVE/fullchain.pem"
    chmod 600 "$CERT_LIVE/privkey.pem"
    log "Certificat Let's Encrypt obtenu pour $DOMAIN"
  else
    warn "Le certificat Let's Encrypt pour $DOMAIN n'a pas pu être obtenu."
    warn "Si Cloudflare Proxy est actif, vérifiez le mode SSL et l'accessibilité HTTP du challenge ACME."
    warn "Le serveur reste disponible en HTTP afin de permettre une correction sans réinstallation."
  fi
fi

# ---------- HTTPS ----------
if [[ "$CERT_OK" -eq 1 ]]; then
  log "Activation HTTPS pour $DOMAIN"

  # The CA may return success while the live/ symlinks are not immediately
  # visible on unusual filesystems. Resolve the real certificate location and
  # fail loudly instead of silently leaving the server in HTTP mode.
  CERT_FULLCHAIN="$CERT_LIVE/fullchain.pem"
  CERT_PRIVKEY="$CERT_LIVE/privkey.pem"

  if [[ ! -s "$CERT_FULLCHAIN" || ! -s "$CERT_PRIVKEY" ]]; then
    REAL_LIVE="$(find "$APP_DIR/certbot/conf/live" -maxdepth 2 -type f \
      \( -name fullchain.pem -o -name privkey.pem \) -printf '%h\n' 2>/dev/null | sort -u | head -1 || true)"
    if [[ -n "$REAL_LIVE" && -s "$REAL_LIVE/fullchain.pem" && -s "$REAL_LIVE/privkey.pem" ]]; then
      mkdir -p "$CERT_LIVE"
      ln -sfn "$REAL_LIVE/fullchain.pem" "$CERT_LIVE/fullchain.pem"
      ln -sfn "$REAL_LIVE/privkey.pem" "$CERT_LIVE/privkey.pem"
    fi
  fi

  [[ -s "$CERT_FULLCHAIN" ]] || fail "Certificat fullchain.pem introuvable après émission."
  [[ -s "$CERT_PRIVKEY" ]] || fail "Clé privkey.pem introuvable après émission."

  chmod 755 "$APP_DIR/certbot/conf" "$APP_DIR/certbot/conf/live" "$CERT_LIVE" 2>/dev/null || true
  chmod 644 "$CERT_FULLCHAIN"
  chmod 600 "$CERT_PRIVKEY"

  render_nginx_https

  # Validate the exact production config before recreating Nginx.
  docker compose up -d --force-recreate nginx
  sleep 1
  docker exec enspy-nginx-1 nginx -t >/dev/null || {
    docker compose logs --tail=100 nginx >&2 || true
    fail "La configuration Nginx HTTPS est invalide."
  }

  log "Vérification HTTPS"
  HTTPS_OK=0
  for i in $(seq 1 60); do
    if curl --noproxy '*' -fsS --max-time 8 --resolve "$DOMAIN:443:127.0.0.1" \
        "https://$DOMAIN/api/healthz" 2>/dev/null | grep -q '"status"'; then
      HTTPS_OK=1
      break
    fi
    sleep 2
  done

  if [[ "$HTTPS_OK" -ne 1 ]]; then
    echo
    echo "[ENSPY] Diagnostic HTTPS:" >&2
    docker compose ps >&2 || true
    docker compose logs --tail=120 nginx >&2 || true
    ss -lntp | grep -E ':(80|443)\s' >&2 || true
    fail "HTTPS est configuré mais le test https://$DOMAIN/api/healthz échoue."
  fi
else
  log "HTTPS non activé : fonctionnement HTTP conservé"
fi

# ---------- Automatic renewal ----------
RENEW_SCRIPT="/usr/local/sbin/enspy-cert-renew"
cat > "$RENEW_SCRIPT" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR="$APP_DIR"
DOMAIN="$DOMAIN"
cd "\$APP_DIR"
if [[ -s "certbot/conf/live/\$DOMAIN/fullchain.pem" ]]; then
  docker compose --profile certbot run --rm certbot renew --quiet
  docker compose exec -T nginx nginx -t >/dev/null
  docker compose exec -T nginx nginx -s reload >/dev/null 2>&1 || true
fi
EOF
chmod 700 "$RENEW_SCRIPT"

cat > /etc/systemd/system/enspy-cert-renew.service <<EOF
[Unit]
Description=Renew ENSPY Let's Encrypt domain certificate
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=$RENEW_SCRIPT
EOF

cat > /etc/systemd/system/enspy-cert-renew.timer <<'EOF'
[Unit]
Description=Renew ENSPY domain certificate twice daily

[Timer]
OnBootSec=30min
OnUnitActiveSec=12h
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now enspy-cert-renew.timer

# ---------- Final end-to-end verification ----------
log "Vérification finale des services"
docker compose ps

curl -fsS --max-time 8 http://127.0.0.1/api/healthz | grep -q '"status"' || fail "Test final HTTP /api/healthz échoué."

if [[ "$CERT_OK" -eq 1 ]]; then
  curl -fsS --max-time 8 --resolve "$DOMAIN:443:127.0.0.1" \
    "https://$DOMAIN/api/healthz" | grep -q '"status"' || fail "Test final HTTPS /api/healthz échoué."
fi

if ! ss -ltnp | grep -Eq ':80\s'; then fail "Le port 80 n'est pas en écoute après le déploiement."; fi
if [[ "$CERT_OK" -eq 1 ]] && ! ss -ltnp | grep -Eq ':443\s'; then fail "Le port 443 n'est pas en écoute alors que HTTPS est activé."; fi

echo
log "DÉPLOIEMENT ENSPY TERMINÉ"
echo "  IP publique : $PUBLIC_IP"
if [[ "$CERT_OK" -eq 1 ]]; then
  echo "  URL publique : https://$DOMAIN/"
  echo "  API          : https://$DOMAIN/api/"
  echo "  Certificat   : Let's Encrypt / domaine"
  echo "  Renouvellement : systemd timer toutes les 12 heures"
else
  echo "  URL publique : http://$DOMAIN/ (DNS à corriger si nécessaire)"
  echo "  API          : http://$DOMAIN/api/"
  echo "  HTTPS        : non obtenu automatiquement (voir avertissement ci-dessus)"
fi
echo "  Health       : /api/healthz"
echo
echo "  Android : l'application ENSPY conserve son mécanisme existant de configuration de l'URL API."
echo "            Utilisez l'URL HTTPS ci-dessus lorsque le certificat du domaine est actif."
echo
echo "  Administrateur initial : $ADMIN_EMAIL"
echo "  Mot de passe initial unique : $ADMIN_INITIAL_PASSWORD"
echo "  IMPORTANT : changez ce mot de passe après la première connexion."
echo
echo "  Données persistantes : PostgreSQL + uploads (aucun volume supprimé par cet installateur)."
echo "  Pour diagnostiquer : cd $APP_DIR && ./diagnose.sh"
