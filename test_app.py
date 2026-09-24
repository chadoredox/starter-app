"""Tests de l'application.

Chaque test est isolé : les appels à Redis sont mockés afin de ne pas
dépendre d'un conteneur externe durant les tests unitaires classiques.
test_health_unreachable vérifie explicitement le comportement 503
lorsque Redis est injoignable.
"""

from unittest.mock import patch

import pytest

from app import app, get_redis_client


@pytest.fixture
def client():
    """Client de test Flask."""
    with app.test_client() as client:
        yield client


def test_health_endpoint(client):
    """Le healthcheck retourne 200 quand Redis répond."""
    with patch.object(app, "get_redis_client") as mock_get:
        mock_get.return_value.ping.return_value = True
        response = client.get("/health")
        assert response.status_code == 200
        assert response.get_json()["status"] == "ok"


def test_health_unreachable(client):
    """Le healthcheck retourne 503 quand Redis est injoignable."""
    with patch.object(app, "get_redis_client") as mock_get:
        import redis as redis_lib
        mock_get.return_value.ping.side_effect = redis_lib.exceptions.ConnectionError(
            "Connection refused"
        )
        response = client.get("/health")
        assert response.status_code == 503
        assert response.get_json()["status"] == "redis unreachable"


def test_status_endpoint(client):
    """L'endpoint /status renvoie les informations du service."""
    response = client.get("/status")
    assert response.status_code == 200
    data = response.get_json()
    assert data["service"] == "projet-devops-groupe-demo"
    assert data["version"] == "1.0"


def test_visits_endpoint(client):
    """Le endpoint /visits incrémente et retourne le compteur."""
    with patch.object(app, "get_redis_client") as mock_get:
        mock_client = mock_get.return_value
        mock_client.incr.return_value = 42
        response = client.get("/visits")
        assert response.status_code == 200
        assert response.get_json()["visits"] == 42


def test_alert_threshold():
    """Le seuil d'alerte est bien 25."""
    from app import alert_threshold
    assert alert_threshold() == 25


def test_sanitize_input():
    """Les chevrons sont échappés."""
    from app import sanitize_input
    assert sanitize_input("<script>") == "&lt;script&gt;"
    assert sanitize_input("sain") == "sain"
