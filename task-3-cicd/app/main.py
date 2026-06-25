import os

import psycopg
from fastapi import FastAPI, HTTPException

app = FastAPI(title="Task 3 Sample API")


@app.get("/")
def root():
    return {"message": "Task 3 GitLab CI/CD sample app"}


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    return {"status": "ready"}


@app.get("/db-check")
def db_check():
    database_url = os.getenv("DATABASE_URL")
    # DATABASE_URL: will import it using env variable
    # export DATABASE_URL="postgresql://<username>:<password>@127.0.0.1:5432/<Database name>"

    if not database_url:
        raise HTTPException(
            status_code=503,
            detail="DATABASE_URL is not configured",
        )

    try:
        with psycopg.connect(database_url, connect_timeout=3) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1;")
                result = cur.fetchone()[0]

        return {"database": "ok", "result": result}

    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Database connection failed",
        ) from exc
