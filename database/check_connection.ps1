$ErrorActionPreference = "Stop"

$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"

if (-not (Test-Path $psql)) {
    throw "psql nije pronadjen na $psql"
}

$env:PGPASSWORD = "makaze_password"
try {
    & $psql -h localhost -p 5432 -U makaze -d makaze_db -c "SELECT current_database(), current_user;"
    if ($LASTEXITCODE -ne 0) {
        throw "Ne mogu se povezati na makaze_db kao korisnik makaze."
    }
}
finally {
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}
