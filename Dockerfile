# Étape 1 : installation des dépendances dans un venv isolé
FROM python:3.12-slim AS build
WORKDIR /build
COPY requirements.txt .
RUN python -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# Étape 2 : image finale légère, exécutée sans privilèges root
FROM python:3.12-slim
ENV PATH="/opt/venv/bin:$PATH" PYTHONUNBUFFERED=1
WORKDIR /srv
COPY --from=build /opt/venv /opt/venv
COPY app ./app
RUN useradd --system --no-create-home appuser && mkdir /data && chown appuser /data
ENV AUTH_DB_PATH=/data/auth.db
VOLUME /data
USER appuser
EXPOSE 8000
# AUTH_SECRET_KEY doit être fourni à l'exécution : docker run -e AUTH_SECRET_KEY=...
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
