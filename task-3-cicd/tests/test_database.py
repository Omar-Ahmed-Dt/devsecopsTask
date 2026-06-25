import os

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_database_check():
    assert os.getenv("DATABASE_URL"), "DATABASE_URL must be set for DB tests"

    response = client.get("/db-check")

    assert response.status_code == 200
    assert response.json()["database"] == "ok"
    assert response.json()["result"] == 1
