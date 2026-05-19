$ErrorActionPreference = "Stop"

$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"

if (-not (Test-Path $psql)) {
    throw "psql nije pronadjen na $psql"
}

$databaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$setupSql = Join-Path $databaseDir "setup_local_postgres.sql"
$schemaSql = Join-Path $databaseDir "schema.sql"

Write-Host "Korak 1/2: pravim user 'makaze' i bazu 'makaze_db'."
Write-Host "Ako zatrazi lozinku, unesi lozinku za PostgreSQL admin korisnika 'postgres'."
& $psql -h localhost -U postgres -d postgres -f $setupSql
if ($LASTEXITCODE -ne 0) {
    throw "Nije uspjelo logovanje kao PostgreSQL korisnik 'postgres'. Provjeri lozinku za postgres admin nalog."
}

Write-Host "Korak 2/2: ucitavam Makaze schemu u makaze_db."
$env:PGPASSWORD = "makaze_password"
try {
    & $psql -h localhost -U makaze -d makaze_db -f $schemaSql
    if ($LASTEXITCODE -ne 0) {
        throw "Nije uspjelo ucitavanje schema.sql kao korisnik 'makaze'."
    }
}
finally {
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}

Write-Host "Gotovo. Baza makaze_db je spremna."
