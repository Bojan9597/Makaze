import paramiko
import sys
import time

# Define server details
SERVER_IP = "76.13.140.158"
SERVER_USER = "root"
SERVER_PASS = "Pijanista123()"
REMOTE_DIR = "/var/www/server_global"

def deploy():
    print(f"Connecting to {SERVER_IP}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        ssh.connect(SERVER_IP, username=SERVER_USER, password=SERVER_PASS)
        print("Connected via SSH.")
        
        sftp = ssh.open_sftp()
        
        files_to_upload = [
            "api.py",
            "database.py",
            "badge_service.py",
        ]
        for local_path in files_to_upload:
            remote_path = f"{REMOTE_DIR}/{local_path}"
            print(f"Uploading {local_path} to {remote_path}...")
            sftp.put(local_path, remote_path)
            
        sftp.close()
        print("Files uploaded.")

        # Force DB port in remote .env to PgBouncer (6432)
        print("Ensuring remote .env uses PgBouncer (DB_PORT=6432)...")
        env_cmd = (
            f"if [ -f {REMOTE_DIR}/.env ]; then "
            f"if grep -q '^DB_PORT=' {REMOTE_DIR}/.env; then "
            f"sed -i 's/^DB_PORT=.*/DB_PORT=6432/' {REMOTE_DIR}/.env; "
            f"else echo 'DB_PORT=6432' >> {REMOTE_DIR}/.env; fi; fi"
        )
        ssh.exec_command(env_cmd)[1].channel.recv_exit_status()

        # Restart Service
        print("Restarting echo_history.service...")
        stdin, stdout, stderr = ssh.exec_command("systemctl restart echo_history.service")
        
        # Wait for completion
        exit_status = stdout.channel.recv_exit_status()
        
        if exit_status == 0:
            print("Service restarted successfully.")
        else:
            print("Service restart failed.")
            print("Error:")
            print(stderr.read().decode())

    except Exception as e:
        print(f"Deployment failed: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    deploy()
