# Étape 2 — Toujours une seule étape et une image de base complète,
# mais avec un utilisateur applicatif non-root et un contexte de build filtré.
# (le multi-stage et l'image slim arrivent à l'étape 3)
FROM python:3.12

WORKDIR /app

# Instructions nécessitant root : installation des dépendances
# et création de l'utilisateur applicatif — USER doit venir APRÈS,
# sinon ces RUN échoueraient en permission denied (piège classique d'ordre)
COPY requirements.txt .
RUN pip install -r requirements.txt \
    && useradd --create-home --shell /bin/bash appuser

# Les fichiers copiés appartiennent à appuser (et plus à root)
COPY --chown=appuser:appuser . .

EXPOSE 5000

ENV FLASK_APP=app.py

# On bascule en non-root juste avant le lancement de l'application
USER appuser

CMD ["flask", "run", "--host=0.0.0.0"]
