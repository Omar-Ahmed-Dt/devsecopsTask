# Run App
```sh
# Create a clean virtualenv:
python3 -m venv .venv
source .venv/bin/activate

# Install app dependencies:
python -m pip install --upgrade pip
pip install -r requirements.txt

# Install local test/CI tools:
pip install pytest httpx pytest-cov ruff bandit pip-audit psycopg2-binary

# Run the DB:
docker run -d \
  --name task3-postgres \
  -e POSTGRES_DB=app_test \
  -e POSTGRES_USER=app \
  -e POSTGRES_PASSWORD=app_test_password \
  -p 5432:5432 \
  postgres:16-alpine

# Run the App:
uvicorn app.main:app --reload --host 127.0.0.1 --port <Port>
export DATABASE_URL="postgresql://app:app_test_password@127.0.0.1:5432/app_test"

# Test it:
curl http://127.0.0.1:8000/
curl http://127.0.0.1:8000/healthz
curl http://127.0.0.1:8000/readyz

# Open Swagger UI:
http://127.0.0.1:8000/docs
```

# Unit Test
It checks if your app logic works
```sh
source .venv/bin/activate
mkdir -p reports
PYTHONPATH="$PWD" pytest -v tests --junitxml=reports/junit.xml
```

# Code Quality And Security Checks
```sh
# Also test lint and scans locally:
ruff check .
bandit -r app -lll -ii
pip-audit -r requirements.txt
```

```sh
docker build -t task3-fastapi:$(git rev-parse --short HEAD)
docker run --rm -p 9090:9090 task3-fastapi:$(git rev-parse --short HEAD)

# Using Docker Compose 
docker-compose up --build

# Check App Image
docker image ls | grep $(git rev-parse --short HEAD)
```
