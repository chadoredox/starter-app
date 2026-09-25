import os

import redis
from flask import Flask, jsonify

app = Flask(__name__)

ALERT_THRESHOLD = 25

# Nom du service Redis sur le réseau Compose (ni localhost, ni IP fixe)
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))


def get_redis_client():
    """Cree un client Redis pointant vers le service 'redis' du reseau Compose."""
    return redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)


def alert_threshold():
    """Seuil d'alerte au-dessus duquel une notification est declenchee."""
    return ALERT_THRESHOLD


def sanitize_input(value):
    """Echappe les caracteres dangereux d'une entree utilisateur."""
    return value.replace("<", "&lt;").replace(">", "&gt;")


@app.route("/health")
def health():
    """Healthcheck véritable : vérifie la connexion à Redis (PING).
    Retourne 200 si Redis répond, 503 sinon — afin que les outils de
    déploiement (ex. deploy.sh) puissent distinguer une version saine
    d'une version dégradation."""
    try:
        client = app.get_redis_client()
        client.ping()
        return jsonify(status="ok"), 200
    except (redis.exceptions.ConnectionError, redis.exceptions.TimeoutError) as exc:
        return jsonify(status="redis unreachable", error=str(exc)), 503


@app.route("/status")
def status():
    color = os.environ.get("COLOR", "unknown")
    return jsonify(service="projet-devops-groupe-demo", version="1.0", color=color), 200


@app.route("/deploy/status")
def deploy_status():
    """Dashboard de monitoring blue/green.

    Retourne l'état complet du déploiement :
    - color : couleur de cette instance (blue / green / unknown)
    - active_color : couleur actuellement routée par nginx
      (lue depuis ACTIVE_COLOR, défaut blue)
    - healthy : booléen — True si Redis répond (cette instance est exploitable)
    - visits : compteur total de visites stocké dans Redis (0 si injoignable)
    """
    active_color = os.environ.get("ACTIVE_COLOR", "blue")
    color = os.environ.get("COLOR", "unknown")

    # Santé Redis et compteur de visites
    healthy = False
    visits = None
    try:
        client = app.get_redis_client()
        client.ping()
        healthy = True
        visits = client.get("visits")
        if visits is not None:
            visits = int(visits)
    except (redis.exceptions.ConnectionError, redis.exceptions.TimeoutError):
        pass

    return jsonify(
        color=color,
        active_color=active_color,
        healthy=healthy,
        visits=visits,
    ), 200


@app.route("/visits")
def visits():
    client = app.get_redis_client()
    count = client.incr("visits")
    return jsonify(visits=count), 200


if __name__ == "__main__":
    app.run(debug=True)

# Attacher le helper comme méthode de l'instance app, pour que les tests
# puissent le mocker facilement avec patch.object(app, "get_redis_client").
app.get_redis_client = get_redis_client
