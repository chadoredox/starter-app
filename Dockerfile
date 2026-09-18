# Étape 1 — Premier Dockerfile volontairement naïf :
# une seule étape, image de base complète, réflexe le plus direct.
# (la taille, la sécurité et la production sont l'objet des étapes suivantes)
FROM python:3.12

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

EXPOSE 5000

ENV FLASK_APP=app.py

CMD ["flask", "run", "--host=0.0.0.0"]
