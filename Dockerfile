# Étape 3 — Multi-stage build :
# un stage "builder" avec l'image complète pour installer les dépendances,
# un stage final sur image slim qui ne récupère que le strict nécessaire
# à l'exécution (venv + code), et gunicorn à la place du serveur de dev Flask.

# ---- Stage 1 : builder -------------------------------------------------
# Image complète : elle contient tout ce qu'il faut pour construire/compile
# les dépendances. Tout ce qui est installé ici reste confiné dans ce stage.
FROM python:3.12 AS builder

# Environnement virtuel isolé : les paquets y sont installés proprement,
# et il suffira de copier ce dossier vers le stage final
RUN python -m venv /opt/venv

# Piège de l'énoncé : cette variable de chemin est propre à CE stage
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---- Stage 2 : final ---------------------------------------------------
# Image slim : pas de compilateurs, pas d'outils de build, pas de cache pip.
FROM python:3.12-slim

# Le PATH déclaré dans le builder ne survit pas au changement de stage :
# il faut le redéclarer ici pour que "gunicorn" soit trouvé (piège classique)
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

RUN useradd --create-home --shell /bin/bash appuser

# Seul le venv construit par le builder est rapatrié — rien d'autre
# (pas de pip, pas de cache, pas les outils de l'image complète)
COPY --from=builder --chown=appuser:appuser /opt/venv /opt/venv

# Strictement nécessaire à l'exécution : le code de l'application
COPY --chown=appuser:appuser app.py .

USER appuser

EXPOSE 5000

# Serveur WSGI de production — jamais le serveur de dev Flask en dehors
# du poste du développeur
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]

# Healthcheck : urllib (bibliothèque standard Python) plutôt que curl,
# absent des images slim — pas de dépendance externe
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1
