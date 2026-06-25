# Run App Locally
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
export IMAGE_TAG="$(git rev-parse --short HEAD)"
docker-compose up --build

# Check App Image
docker image ls | grep $(git rev-parse --short HEAD)
```

# Run App in Kubernetes
## CI/CD Variables 
Need to Create below CI/CD variables in `gitlab`
```text
# repo => settings => ci/cd => variables => Add variables
KUBE_CONFIG_STAGING
POSTGRES_DB
POSTGRES_PASSWORD
POSTGRES_USER
```

## From Local to Gitlab to run CI/CD Pipelines
```sh
git remove -v
git remote add gitlab <repo link> 

# push to github and gitlab
git push origin main
git push gitlab main
```

- Check [Kubernetes deployments evidence](./evidence.txt)

# Summary
- The pipeline is split into seven stages: install, test, security, build, scan, push, and deploy.
    - **Install**: 
        - it uses the `python:3.12-slim` image to install the application dependencies and required CI tools. Pip downloads are cached and reused by other jobs/runs to improve pipeline performance.
        - it generates a `pip-freeze.txt` file as an artifact to capture the exact versions of installed packages
    - **Test**:
        - Application tests a real PostgreSQL service using GitLab CI services
    - **Security**: 
        - the pipeline runs `ruff`, `bandit`, and `pip-audit`. `ruff` enforces code quality, bandit performs static application security testing (SAST) for Python code, and pip-audit checks dependencies for known vulnerabilities. This stage introduces security checks before building and publishing the container image.
    - **Build**:
        - Docker builds the FastAPI image and tags it with the Git commit SHA
    - **Scan**:
        - Trivy scans the built image before it is pushed to the registry. The pipeline is configured to fail if high or critical vulnerabilities are detected, preventing insecure images from being published.
    - **Push**: 
        - pushed to the GitLab Container Registry. This step is restricted to the main branch to reduce the risk of publishing images from feature or test branches.
    - **Deploy**: 
        - Deploy to DigitalCcean Kubernetes cluster is preformed manually using `when:
          manual`
        - using `kubectl` can deploy all manifest files: `app` is deployed as `deployment` object and `database` is deployed as `StatefulSet` object 

