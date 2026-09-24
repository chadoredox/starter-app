# Starter App — Projet DevOps (Séance 2, ESIEA)

[![CI Pipeline](https://github.com/chadoredox/starter-app/actions/workflows/ci.yml/badge.svg)](https://github.com/chadoredox/starter-app/actions/workflows/ci.yml)

Petite application Flask servant de support à l'atelier **Pipeline CI avec GitHub Actions**.

## Le pipeline CI

Le workflow (`.github/workflows/ci.yml`) se déclenche automatiquement sur **push** et sur **pull request** vers `master`. Il enchaîne deux jobs :

1. **`lint`** — vérifie le style du code avec `flake8` (max-line-length = 100)
2. **`test`** — exécute les tests unitaires avec `pytest` (4 tests), en **matrice parallèle sur Python 3.10, 3.11 et 3.12**, avec génération d'un rapport de couverture HTML conservé en artefact téléchargeable (même en cas d'échec)

Le job `test` dépend de `lint` (`needs: lint`) : si le style est en faute, les tests ne démarrent pas (fail-fast). Les dépendances pip sont mises en cache (`actions/cache`, clé basée sur le contenu de `requirements.txt`) pour accélérer les runs suivants.

La branche `master` est **protégée** : tout merge exige que les 4 checks CI passent (y compris pour l'administrateur du dépôt).

## Application

| Élément | Description |
|---------|-------------|
| `alert_threshold()` | Seuil d'alerte (25) au-dessus duquel une notification est déclenchée |
| `sanitize_input(value)` | Échappe les caractères dangereux (`<` → `&lt;`, `>` → `&gt;`) |
| `GET /health` | Statut du service (`{"status": "ok"}`) |
| `GET /status` | Nom du service et version (`{"service": "...", "version": "1.0"}`) |

## Lancer en local

```bash
python3 -m venv .venv && source .venv/bin/activate   # Windows : .venv\Scripts\activate
pip install -r requirements.txt
pytest --cov=app -v
flake8 . --max-line-length=100 --exclude=.venv
```

## Suivi de l'atelier CI/CD — séquences 2, 3 et 4

### Séquence 2 — CI (8 étapes)
- ✅ Étape 1 — Découverte de l'application fournie
- ✅ Étape 2 — Premier workflow minimal (`actions/checkout` + `actions/setup-python`)
- ✅ Étape 3 — Déclencheurs push & pull request (push restreint à `master`)
- ✅ Étape 4 — Job `lint` séparé + `needs:` + test ajouté pour `/status`
- ✅ Étape 5 — Matrix build (Python 3.10 / 3.11 / 3.12)
- ✅ Étape 6 — Cache pip (`hashFiles`) + rapport de couverture en artefact (`if: always()`)
- ✅ Étape 7 — Protection de branche : checks obligatoires, testée avec PR cassée puis corrigée (PR #1)
- ✅ Étape 8 — Badge CI + documentation

### Séquence 3 — Docker (6 étapes)
- ✅ Étape 1 — Premier Dockerfile naïf (single-stage, python:3.12, vérifié avec docker run + curl)
- ✅ Étape 2 — Utilisateur non-root (`appuser`) + `.dockerignore` (50 MB → 4 KB sur la couche COPY)
- ✅ Étape 3 — Multi-stage build : `builder` (python:3.12) → `final` (python:3.12-slim, gunicorn)
- ✅ Étape 4 — Mesure avant/après : 1.13 Go → 151 Mo (−86.7%, ×7.5 plus léger)
- ✅ Étape 5 — Docker Compose multi-services (`web` + `redis`, réseau `app-net`, volume `redis-data`)
- ✅ Étape 6 — Healthcheck sur les deux services, `depends_on: condition: service_healthy`

### Séquence 4 — Pipeline CI/CD bout-en-bout (6 étapes, en cours)
- ✅ Étape 1 — `/health` vérifie Redis (PING) : 200 si OK, 503 si Redis injoignable
- ✅ Étape 2 — Job `build-and-push` : construit l'image multi-stage et la pousse sur GHCR
            avec tag SHA (immuable) + `latest` sur master. Déclenché uniquement par push (pas par PR).
            Nécessite `permissions: packages: write` activé dans Settings > Actions.

## Conteneurisation — détails de l'image finale

Le `Dockerfile` multi-stage utilise :
- **Stage `builder`** : image complète `python:3.12`, installe le venv dans `/opt/venv` avec `--no-cache-dir`
- **Stage final** : `python:3.12-slim`, recopie uniquement `/opt/venv` + `app.py`, tourne en `appuser`, expose `gunicorn --bind 0.0.0.0:5000`
- **HEALTHCHECK** : `python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"` — aucune dépendance externe (pas de curl)

Reproduction locale :
```bash
docker compose up -d
curl http://localhost:5000/health          # → {"status":"ok"}
curl http://localhost:5000/visits          # → {"visits":N}
docker compose down
```

