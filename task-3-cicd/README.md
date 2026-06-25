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

# Run the app:
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000

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
