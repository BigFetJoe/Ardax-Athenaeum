FROM python:3.12-slim

WORKDIR /app

# Copia so o requirements primeiro: enquanto ele nao mudar, o Docker
# reaproveita a camada do pip install e o build fica rapido.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# No A2b nao usamos este comando -- rodamos "alembic upgrade head" por fora.
# Ele passa a valer no A3, quando a API existir.
CMD ["uvicorn", "ardax.main:app", "--host", "0.0.0.0", "--port", "8000"]
