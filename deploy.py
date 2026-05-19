#!/usr/bin/env python3
"""
Deploy Makaze to a Linux VPS.

Što radi:
  1. Builda Flutter web sa serverskim IP-om kao API_BASE_URL
  2. SSH-om na server:
     - Instalira Nginx ako nije
     - Kreira /var/www/makaze/{api,web,uploads}
     - Uploada Flask API + Flutter web build
     - Kreira Python venv + instalira deps
     - Piše .env fajl
     - Kreira systemd servis (makaze-api)
     - Kreira Nginx config
     - Inicijalizuje DB šemu
     - Startuje sve servise

Pokretanje:
    pip install paramiko
    python deploy.py
"""

import os
import sys
import subprocess
import paramiko
import stat
import posixpath

# ---------------------------------------------------------------------------
# CONFIG — promijeni prema svom serveru
# ---------------------------------------------------------------------------
SERVER_IP   = "76.13.140.158"
SERVER_USER = "root"
SERVER_PASS = "pass"   # ili postavi env var DEPLOY_PASS

REMOTE_BASE = "/var/www/makaze"
SERVICE_NAME = "makaze-api"

# PostgreSQL na serveru (podesi za svoju bazu)
DB_URL = f"postgresql://makaze:makaze_password@localhost:5432/makaze_db"
JWT_SECRET = "PROMIJENI_OVO_PRIJE_PRODUKCIJE_abc123xyz"
# ---------------------------------------------------------------------------

LOCAL_API_DIR = os.path.join(os.path.dirname(__file__), "api")
LOCAL_WEB_DIR = os.path.join(os.path.dirname(__file__), "app", "build", "web")
LOCAL_DB_DIR  = os.path.join(os.path.dirname(__file__), "database")

API_FILES = [
    "app.py",
    "requirements.txt",
]


def run_local(cmd, cwd=None):
    print(f"  $ {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=cwd)
    if result.returncode != 0:
        print(f"FAILED (exit {result.returncode})")
        sys.exit(1)


def ssh_run(ssh, cmd, check=True):
    print(f"  [ssh] {cmd}")
    _, stdout, stderr = ssh.exec_command(cmd)
    exit_code = stdout.channel.recv_exit_status()
    out = stdout.read().decode().strip()
    err = stderr.read().decode().strip()
    if out:
        print(f"        {out}")
    if err and exit_code != 0:
        print(f"  ERR   {err}")
    if check and exit_code != 0:
        print(f"  Command failed (exit {exit_code})")
        sys.exit(1)
    return out


def sftp_mkdir(sftp, remote_path):
    parts = remote_path.split("/")
    current = ""
    for part in parts:
        if not part:
            current = "/"
            continue
        current = posixpath.join(current, part)
        try:
            sftp.stat(current)
        except FileNotFoundError:
            sftp.mkdir(current)


def sftp_put_dir(sftp, local_dir, remote_dir):
    """Recursively upload local_dir to remote_dir."""
    sftp_mkdir(sftp, remote_dir)
    for item in os.listdir(local_dir):
        local_path  = os.path.join(local_dir, item)
        remote_path = posixpath.join(remote_dir, item)
        if os.path.isdir(local_path):
            sftp_put_dir(sftp, local_path, remote_path)
        else:
            sftp.put(local_path, remote_path)


def build_flutter():
    print("\n=== 1. Flutter web build ===")
    flutter_dir = os.path.join(os.path.dirname(__file__), "app")
    run_local(
        f'flutter build web --release --dart-define=API_BASE_URL=http://{SERVER_IP}',
        cwd=flutter_dir,
    )
    if not os.path.isdir(LOCAL_WEB_DIR):
        print(f"Build output not found at {LOCAL_WEB_DIR}")
        sys.exit(1)
    print("  Flutter build OK")


def deploy_server():
    print(f"\n=== 2. Connecting to {SERVER_IP} ===")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(SERVER_IP, username=SERVER_USER, password=SERVER_PASS)
    sftp = ssh.open_sftp()
    print("  Connected.")

    # -- directories ---------------------------------------------------------
    print("\n=== 3. Server directories ===")
    for d in [REMOTE_BASE, f"{REMOTE_BASE}/api", f"{REMOTE_BASE}/web",
              f"{REMOTE_BASE}/api/uploads/profiles",
              f"{REMOTE_BASE}/api/uploads/salons"]:
        ssh_run(ssh, f"mkdir -p {d}")

    # -- system packages -----------------------------------------------------
    print("\n=== 4. System packages ===")
    ssh_run(ssh, "apt-get update -qq")
    ssh_run(ssh, "apt-get install -y -qq nginx python3 python3-pip python3-venv")

    # -- upload API ----------------------------------------------------------
    print("\n=== 5. Upload Flask API ===")
    for fname in API_FILES:
        local  = os.path.join(LOCAL_API_DIR, fname)
        remote = f"{REMOTE_BASE}/api/{fname}"
        print(f"  upload {fname}")
        sftp.put(local, remote)

    # also upload schema and seed
    for fname in ["schema.sql", "seed.py", "download_images.py"]:
        local = os.path.join(LOCAL_DB_DIR, fname)
        if os.path.exists(local):
            sftp.put(local, f"{REMOTE_BASE}/api/{fname}")

    # -- .env ----------------------------------------------------------------
    print("\n=== 6. Write .env ===")
    env_content = (
        f"DATABASE_URL={DB_URL}\n"
        f"JWT_SECRET={JWT_SECRET}\n"
        f"FLASK_HOST=0.0.0.0\n"
        f"FLASK_PORT=5001\n"
        f"FLASK_DEBUG=false\n"
        f"UPLOAD_FOLDER={REMOTE_BASE}/api/uploads\n"
        f"PUBLIC_BASE_URL=http://{SERVER_IP}\n"
    )
    with sftp.open(f"{REMOTE_BASE}/api/.env", "w") as f:
        f.write(env_content)

    # -- Python venv ---------------------------------------------------------
    print("\n=== 7. Python venv + dependencies ===")
    ssh_run(ssh, f"python3 -m venv {REMOTE_BASE}/api/.venv")
    ssh_run(ssh, f"{REMOTE_BASE}/api/.venv/bin/pip install -q --upgrade pip")
    ssh_run(ssh, f"{REMOTE_BASE}/api/.venv/bin/pip install -q -r {REMOTE_BASE}/api/requirements.txt")

    # -- database schema -----------------------------------------------------
    print("\n=== 8. Database schema ===")
    pg_user = DB_URL.split("://")[1].split(":")[0]
    pg_pass = DB_URL.split(":")[2].split("@")[0]
    pg_host = DB_URL.split("@")[1].split(":")[0]
    pg_port = DB_URL.split("@")[1].split(":")[1].split("/")[0]
    pg_db   = DB_URL.split("/")[-1]

    # Create role + DB if they don't exist
    ssh_run(ssh,
        f"sudo -u postgres psql -c \""
        f"DO \\$\\$ BEGIN "
        f"IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='{pg_user}') THEN "
        f"CREATE ROLE {pg_user} LOGIN PASSWORD '{pg_pass}'; END IF; END \\$\\$;\"",
        check=False)
    ssh_run(ssh,
        f"sudo -u postgres psql -c \"SELECT 'CREATE DATABASE {pg_db} OWNER {pg_user}' "
        f"WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname='{pg_db}')\\gexec\"",
        check=False)
    ssh_run(ssh,
        f"PGPASSWORD={pg_pass} psql -h {pg_host} -p {pg_port} -U {pg_user} -d {pg_db} "
        f"-f {REMOTE_BASE}/api/schema.sql",
        check=False)

    # -- systemd service -----------------------------------------------------
    print("\n=== 9. Systemd service ===")
    service = f"""[Unit]
Description=Makaze Flask API
After=network.target

[Service]
User=root
WorkingDirectory={REMOTE_BASE}/api
EnvironmentFile={REMOTE_BASE}/api/.env
ExecStart={REMOTE_BASE}/api/.venv/bin/gunicorn -w 2 -b 127.0.0.1:5001 "app:create_app()"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
"""
    with sftp.open(f"/etc/systemd/system/{SERVICE_NAME}.service", "w") as f:
        f.write(service)
    ssh_run(ssh, "systemctl daemon-reload")
    ssh_run(ssh, f"systemctl enable {SERVICE_NAME}")
    ssh_run(ssh, f"systemctl restart {SERVICE_NAME}")

    # -- upload Flutter web --------------------------------------------------
    print("\n=== 10. Upload Flutter web build ===")
    print("  (ovo može potrajati par minuta...)")
    sftp_put_dir(sftp, LOCAL_WEB_DIR, f"{REMOTE_BASE}/web")
    print("  Upload done.")

    # -- Nginx config --------------------------------------------------------
    print("\n=== 11. Nginx config ===")
    nginx_conf = f"""server {{
    listen 80;
    server_name {SERVER_IP};

    # Flutter web app
    root {REMOTE_BASE}/web;
    index index.html;

    # Flask API proxy
    location /api/ {{
        proxy_pass http://127.0.0.1:5001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 60;
        client_max_body_size 10M;
    }}

    # Uploaded images proxy
    location /uploads/ {{
        proxy_pass http://127.0.0.1:5001;
    }}

    # Flutter SPA fallback
    location / {{
        try_files $uri $uri/ /index.html;
    }}
}}
"""
    nginx_site = f"/etc/nginx/sites-available/makaze"
    with sftp.open(nginx_site, "w") as f:
        f.write(nginx_conf)
    ssh_run(ssh, f"ln -sf {nginx_site} /etc/nginx/sites-enabled/makaze", check=False)
    ssh_run(ssh, "rm -f /etc/nginx/sites-enabled/default", check=False)
    ssh_run(ssh, "nginx -t")
    ssh_run(ssh, "systemctl enable nginx")
    ssh_run(ssh, "systemctl restart nginx")

    # -- status check --------------------------------------------------------
    print("\n=== 12. Status ===")
    ssh_run(ssh, f"systemctl is-active {SERVICE_NAME}", check=False)
    ssh_run(ssh, "systemctl is-active nginx", check=False)
    api_check = ssh_run(ssh, "curl -s http://127.0.0.1:5001/health", check=False)
    print(f"  API health: {api_check}")

    sftp.close()
    ssh.close()


def main():
    print("=" * 55)
    print("  Makaze deploy")
    print(f"  Server: {SERVER_IP}")
    print("=" * 55)

    build_flutter()
    deploy_server()

    print("\n" + "=" * 55)
    print(f"  DONE!  http://{SERVER_IP}")
    print("=" * 55)
    print()
    print("Nakon deploya, ako hoces seed podatke:")
    print(f"  ssh root@{SERVER_IP}")
    print(f"  cd {REMOTE_BASE}/api")
    print(f"  .venv/bin/python seed.py")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nAborted.")
    except Exception as e:
        print(f"\nFATAL: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
