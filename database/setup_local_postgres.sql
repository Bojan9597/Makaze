DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'makaze') THEN
        CREATE ROLE makaze LOGIN PASSWORD 'makaze_password';
    ELSE
        ALTER ROLE makaze WITH LOGIN PASSWORD 'makaze_password';
    END IF;
END $$;

SELECT 'CREATE DATABASE makaze_db OWNER makaze'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'makaze_db')\gexec

GRANT ALL PRIVILEGES ON DATABASE makaze_db TO makaze;
