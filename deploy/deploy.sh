#!/usr/bin/env bash
# deploy.sh — Bascule blue/green avec rollback automatique.
#
# Usage :
#   ./deploy/deploy.sh [blue|green]
#
# Comportement :
#   1. Détermine la couleur inactive (celle qui n'est pas ACTIVE_COLOR).
#   2. Démarre le service inactive avec docker compose.
#   3. Attente que le service soit healthy (smoke test en boucle).
#   4. Si smoke test réussi : bascule nginx vers la nouvelle couleur,
#      puis arrête l'ancienne version.
#   5. Si smoke test échoue : ne touche PAS à la couleur active,
#      arrête le service démarré et sort avec erreur.
#
# État persisté dans deploy/.active-color (simple fichier texte).
#
# Prérequis :
#   - docker compose installé
#   - Le fichier deploy/.active-color contient "blue" ou "green"
#   - Si le fichier n'existe pas, la couleur active par défaut est "blue"

set -euo pipefail

COMPOSE_PROJECT="starter-app2"
DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_FILE="$DEPLOY_DIR/.active-color"
HEALTH_URL="http://localhost:8080/health"
STATUS_URL="http://localhost:8080/status"
MAX_RETRIES=30
RETRY_INTERVAL=5

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[deploy]${NC} $*"; }
warn() { echo -e "${YELLOW}[deploy]${YELLOW} WARN: $*${NC}"; }
err()  { echo -e "${RED}[deploy]${RED} ERROR: $*${NC}" >&2; }

get_active_color() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "blue"
    fi
}

get_inactive_color() {
    local active
    active=$(get_active_color)
    if [ "$active" = "blue" ]; then
        echo "green"
    else
        echo "blue"
    fi
}

get_current_color() {
    # Lit la couleur que nginx route actuellement (via /status).
    # Retourne "blue", "green" ou "" si nginx n'est pas joignable.
    curl -s "$STATUS_URL" 2>/dev/null \
        | grep -o '"color":"[^"]*"' \
        | cut -d'"' -f4 || echo ""
}

smoke_test() {
    local expected_color="$1"
    local attempt=0

    while [ $attempt -lt $MAX_RETRIES ]; do
        attempt=$((attempt + 1))
        log "Smoke test ($attempt/$MAX_RETRIES) — vérifie app-$expected_color..."

        # Santé du conteneur (inspect direct, bypass nginx)
        local container_status
        container_status=$(docker inspect "starter-app2-app-${expected_color}-1" \
            --format '{{.State.Health.Status}}' 2>/dev/null || echo "not_found")

        # Réponse API sur le port direct du conteneur
        local api_ok
        api_ok=$(docker exec "starter-app2-app-${expected_color}-1" \
            python -c "
import urllib.request, sys
try:
    r = urllib.request.urlopen('http://localhost:5000/health', timeout=3)
    print(r.status)
except Exception:
    sys.exit(1)
" 2>/dev/null || echo "unreachable")

        if [ "$container_status" = "healthy" ] && [ "$api_ok" = "200" ]; then
            log "✅ Smoke test réussi : app-$expected_color healthy (container + API)"
            return 0
        fi

        log "  → container=$container_status  api=$api_ok  (attend…)"
        sleep $RETRY_INTERVAL
    done

    err "Smoke test échoué après $MAX_RETRIES tentatives — rollback"
    return 1
}

# ── Principal ─────────────────────────────────────────────────────────
main() {
    local requested_color="${1:-}"

    # Si aucune couleur demandée, on bascule vers l'inverse
    if [ -z "$requested_color" ]; then
        local active
        active=$(get_active_color)
        requested_color=$(get_inactive_color)
        log "Aucune couleur spécifiée — bascule de $active vers $requested_color"
    fi

    # Validation
    if [ "$requested_color" != "blue" ] && [ "$requested_color" != "green" ]; then
        err "Couleur invalide : '$requested_color'. Attendu : blue ou green"
        exit 1
    fi

    local active
    active=$(get_active_color)

    # Vérifier si la couleur demandée est réellement routée par nginx
    local current
    current=$(get_current_color)
    if [ "$requested_color" = "$active" ] && [ "$current" = "$requested_color" ]; then
        warn "La couleur $requested_color est déjà active et routée — rien à faire"
        exit 0
    fi

    local inactive="$active"
    log "Déploiement de $requested_color (actuellement $active actif)"

    # 1. Démarrer la nouvelle version
    log "Démarrage de app-$requested_color..."
    docker compose -p "$COMPOSE_PROJECT" up -d "app-$requested_color"
    log "✅ app-$requested_color démarré"

    # 2. Smoke test
    if ! smoke_test "$requested_color"; then
        err "Le smoke test a échoué — rollback : arrêt de $requested_color"
        docker compose -p "$COMPOSE_PROJECT" stop "app-$requested_color"
        exit 1
    fi

    # 3. Bascule nginx
    log "Bascule nginx vers $requested_color..."
    ACTIVE_COLOR="$requested_color" docker compose -p "$COMPOSE_PROJECT" up -d nginx
    log "✅ Nginx basculé vers $requested_color"

    # 4. Arrêt de l'ancienne version
    log "Arrêt de app-$inactive..."
    docker compose -p "$COMPOSE_PROJECT" stop "app-$inactive"
    log "✅ app-$inactive arrêté"

    # 5. Persistance de l'état
    echo "$requested_color" > "$STATE_FILE"
    log "État mis à jour : $requested_color est maintenant actif"
    log "🎉 Déploiement réussi !"
}

main "$@"
