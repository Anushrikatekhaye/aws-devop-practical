#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

# release hash: ${release_hash}
dnf install -y python3 python3-pip

mkdir -p /opt/app
aws s3 cp "s3://${app_bucket}/release/app.py" /opt/app/app.py --region ${region}
aws s3 cp "s3://${app_bucket}/release/requirements.txt" /opt/app/requirements.txt --region ${region}

python3 -m venv /opt/app/venv
/opt/app/venv/bin/pip install --no-cache-dir -r /opt/app/requirements.txt

useradd --system --no-create-home --shell /sbin/nologin appsvc || true
chown -R appsvc:appsvc /opt/app

cat >/etc/systemd/system/app.service <<'UNIT'
[Unit]
Description=Flask app (gunicorn)
After=network-online.target
Wants=network-online.target

[Service]
User=appsvc
WorkingDirectory=/opt/app
Environment=DB_SECRET_ID=${secret_id}
Environment=AWS_REGION=${region}
Environment=APP_ENV=${environment}
ExecStart=/opt/app/venv/bin/gunicorn --workers 2 --bind 0.0.0.0:8080 app:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now app.service
