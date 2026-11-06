# Etapa 1: instalar dependencias en un venv
FROM python:3.12-slim-bookworm@sha256:a116514e19457bcb7af7efe9c3dd0b9b71e85b317694e7882a1c52aa15a78134 AS build
WORKDIR /src
COPY requirements.txt .
RUN python -m venv /venv && /venv/bin/pip install --no-cache-dir -r requirements.txt

# Etapa 2: imagen final, sin pip, sin compiladores, sin root
FROM python:3.12-slim-bookworm@sha256:a116514e19457bcb7af7efe9c3dd0b9b71e85b317694e7882a1c52aa15a78134
ARG VERSION=dev
ENV APP_VERSION=$VERSION PATH=/venv/bin:$PATH PYTHONUNBUFFERED=1
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin ruleta
COPY --from=build /venv /venv
WORKDIR /app
COPY ruleta.py app.py ./
COPY static static
COPY templates templates
USER 10001
EXPOSE 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--threads", "4", "app:app"]
