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
        client = get_redis_client()
        client.ping()
        return jsonify(status="ok"), 200
    except (redis.exceptions.ConnectionError, redis.exceptions.TimeoutError) as exc:
        return jsonify(status="redis unreachable", error=str(exc)), 503


@app.route("/status")
def status():
    return jsonify(service="projet-devops-groupe-demo", version="1.0"), 200


@app.route("/visits")
def visits():
    client = get_redis_client()
    count = client.incr("visits")
    return jsonify(visits=count), 200


if __name__ == "__main__":
    app.run(debug=True)
