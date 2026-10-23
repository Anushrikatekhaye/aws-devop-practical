"""Sample Flask application for the AWS DevOps practical.

Endpoints
  /          - HTML landing page with instance id and DB status
  /health    - lightweight ALB health check (does not touch the DB)
  /db        - JSON DB connectivity check; credentials come from AWS Secrets Manager
"""
import json
import os
import socket

import boto3
import pymysql
from flask import Flask, jsonify

app = Flask(__name__)

SECRET_ID = os.environ.get("DB_SECRET_ID", "")
REGION = os.environ.get("AWS_REGION", "ap-south-1")
ENVIRONMENT = os.environ.get("APP_ENV", "dev")

_secret_cache = None


def get_db_credentials():
    """Fetch DB credentials from Secrets Manager (cached for the process lifetime)."""
    global _secret_cache
    if _secret_cache is None:
        client = boto3.client("secretsmanager", region_name=REGION)
        resp = client.get_secret_value(SecretId=SECRET_ID)
        _secret_cache = json.loads(resp["SecretString"])
    return _secret_cache


def db_check():
    creds = get_db_credentials()
    conn = pymysql.connect(
        host=creds["host"],
        port=int(creds.get("port", 3306)),
        user=creds["username"],
        password=creds["password"],
        database=creds["dbname"],
        connect_timeout=5,
    )
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT VERSION()")
            return cur.fetchone()[0]
    finally:
        conn.close()


@app.route("/health")
def health():
    return jsonify(status="ok"), 200


@app.route("/db")
def db():
    try:
        version = db_check()
        return jsonify(database="connected", mysql_version=version), 200
    except Exception as exc:  # noqa: BLE001 - surface any failure for diagnostics
        return jsonify(database="error", detail=type(exc).__name__), 503


@app.route("/")
def index():
    try:
        db_status = f"connected (MySQL {db_check()})"
    except Exception as exc:  # noqa: BLE001
        db_status = f"unavailable ({type(exc).__name__})"
    return f"""<!doctype html>
<html><head><meta charset="utf-8"><title>AWS DevOps Practical</title>
<style>body{{font-family:system-ui,sans-serif;max-width:640px;margin:4rem auto;padding:0 1rem}}
code{{background:#eee;padding:2px 6px;border-radius:4px}}</style></head>
<body>
<h1>AWS DevOps Practical</h1>
<p>Served over HTTPS via ALB &rarr; Auto Scaling EC2 &rarr; RDS MySQL.</p>
<ul>
<li>Environment: <code>{ENVIRONMENT}</code></li>
<li>Served by host: <code>{socket.gethostname()}</code></li>
<li>Database: <code>{db_status}</code></li>
</ul>
<p>Endpoints: <code>/health</code>, <code>/db</code></p>
</body></html>"""


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
