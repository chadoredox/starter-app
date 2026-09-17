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

## Suivi de l'atelier (8 étapes)

- ✅ Étape 1 — Découverte de l'application fournie
- ✅ Étape 2 — Premier workflow minimal (`actions/checkout` + `actions/setup-python`)
- ✅ Étape 3 — Déclencheurs push & pull request (push restreint à `master`)
- ✅ Étape 4 — Job `lint` séparé + `needs:` + test ajouté pour `/status`
- ✅ Étape 5 — Matrix build (Python 3.10 / 3.11 / 3.12)
- ✅ Étape 6 — Cache pip (`hashFiles`) + rapport de couverture en artefact (`if: always()`)
- ✅ Étape 7 — Protection de branche : checks obligatoires, testée avec PR cassée puis corrigée (PR #1)
- ✅ Étape 8 — Badge CI + documentation
