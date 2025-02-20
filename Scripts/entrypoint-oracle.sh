#!/usr/bin/env bash
set -e

echo "=== ENTRYPOINT ORACLE ==="

###############################################################################
# 1) Verificar variáveis
###############################################################################
if [ -z "$JDBC" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Faltam variáveis essenciais: JDBC, USERNAME, PASSWORD."
  echo "Faltam variáveis essenciais: JDBC, USERNAME, PASSWORD." >> "$GITHUB_STEP_SUMMARY"
  exit 1
fi

echo "### Oracle Dialect" >> "$GITHUB_STEP_SUMMARY"
echo "JDBC: $JDBC" >> "$GITHUB_STEP_SUMMARY"

# Se for clonar via OCI, cheque as variáveis
if [ -n "$OCI_PDB_ID" ] && [ -n "$OCI_TARGET_CID" ] && [ -n "$OCI_SOURCE_QCARBON_KEY" ] && [ -n "$OCI_TARGET_TDE_WALLET_ID" ]; then
  echo "Clonagem de PDB via OCI habilitada." >> "$GITHUB_STEP_SUMMARY"
else
  echo "Clonagem via OCI não será executada (faltam variáveis)." >> "$GITHUB_STEP_SUMMARY"
fi

###############################################################################
# 2) Extrair host, port e service do JDBC
###############################################################################
if [[ "$JDBC" =~ ^jdbc:oracle:thin:@//([^:]+):([^/]+)/(.+)$ ]]; then
  ORA_HOST="${BASH_REMATCH[1]}"
  ORA_PORT="${BASH_REMATCH[2]}"
  ORA_SERVICE="${BASH_REMATCH[3]}"
else
  echo "JDBC não reconhecido como Oracle: $JDBC"
  echo "JDBC não reconhecido como Oracle: $JDBC" >> "$GITHUB_STEP_SUMMARY"
fi

echo "ORA_HOST: $ORA_HOST"
echo "ORA_PORT: $ORA_PORT"
echo "ORA_SERVICE: $ORA_SERVICE"
echo "Host: $ORA_HOST | Port: $ORA_PORT | Service: $ORA_SERVICE" >> "$GITHUB_STEP_SUMMARY"

###############################################################################
# 3) Checar OCI CLI
###############################################################################
if ! command -v oci &> /dev/null; then
  echo "OCI CLI não instalado. Se precisar de clonagem, vai falhar."
  echo "OCI CLI não instalado. Se precisar de clonagem, vai falhar." >> "$GITHUB_STEP_SUMMARY"
fi

###############################################################################
# 4) Clonar PDB via OCI (exemplo simplificado)
###############################################################################
if [ -n "$OCI_PDB_ID" ] && [ -n "$OCI_TARGET_CID" ] && [ -n "$OCI_SOURCE_QCARBON_KEY" ] && [ -n "$OCI_TARGET_TDE_WALLET_ID" ]; then
  PDB_NAME="P${REPO_NAME:-TEST}"
  echo "Iniciando clonagem de PDB $OCI_PDB_ID -> $PDB_NAME (container=$OCI_TARGET_CID)..." >> "$GITHUB_STEP_SUMMARY"

  # (Aqui entra a lógica de checagem do container, deleção prévia, etc.)
  # ...
  # Exemplo rápido:
  CLONE_JSON="clone-$PDB_NAME.json"
  CLONE_PASSWORD=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 16)

  oci db pluggable-database remote-clone \
    --pluggable-database-id "$OCI_PDB_ID" \
    --target-container-database-id "$OCI_TARGET_CID" \
    --cloned-pdb-name "$PDB_NAME" \
    --pdb-admin-password "$CLONE_PASSWORD" \
    --source-container-db-admin-password "$OCI_SOURCE_QCARBON_KEY" \
    --target-tde-wallet-password "$OCI_TARGET_TDE_WALLET_ID" \
    --output json > "$CLONE_JSON"

  echo "Clonagem solicitada. JSON -> $CLONE_JSON" >> "$GITHUB_STEP_SUMMARY"
  # Esperar PDB ficar AVAILABLE, extrair connection strings...
  # ...
  # Exemplo final DUMMY_ORA_JDBC
  DUMMY_ORA_JDBC="jdbc:oracle:thin:@//dummyHost:1521/dummyService"

  # Rodar Flyway no clone
  echo "Rodando Flyway no clone (DUMMY_ORA_JDBC=$DUMMY_ORA_JDBC)..." >> "$GITHUB_STEP_SUMMARY"
  flyway info clean info \
    -user="$USERNAME" \
    -password="$QA_PASSWORD" \
    -baselineOnMigrate="true" \
    -locations="filesystem:$FLYWAY_LOCATIONS" \
    -url="$DUMMY_ORA_JDBC" \
    -cleanDisabled=false

  flyway info migrate info \
    -user="$USERNAME" \
    -password="$QA_PASSWORD" \
    -baselineOnMigrate="true" \
    -locations="filesystem:$FLYWAY_LOCATIONS" \
    -url="$DUMMY_ORA_JDBC"

  # Excluir a PDB clonada ao final
  echo "Deletando PDB clonada $PDB_NAME..." >> "$GITHUB_STEP_SUMMARY"
  # ...
fi

###############################################################################
# 5) Rodar Flyway no QA (if RUN_ON_QA==true)
###############################################################################
if [ "$RUN_ON_QA" = "true" ]; then
  echo "Executando Flyway em QA ($QA_JDBC)..." >> "$GITHUB_STEP_SUMMARY"
  flyway info repair \
    -user="$USERNAME" \
    -password="$QA_PASSWORD" \
    -url="$QA_JDBC" \
    -locations="filesystem:$FLYWAY_LOCATIONS"

  flyway info migrate info \
    -user="$USERNAME" \
    -password="$QA_PASSWORD" \
    -baselineOnMigrate="true" \
    -locations="filesystem:$FLYWAY_LOCATIONS" \
    -url="$QA_JDBC"
fi

###############################################################################
# 6) Rodar Flyway em PROD (if RUN_ON_PROD==true)
###############################################################################
if [ "$RUN_ON_PROD" = "true" ]; then
  echo "Executando Flyway em PROD ($JDBC)..." >> "$GITHUB_STEP_SUMMARY"
  flyway info repair \
    -user="$USERNAME" \
    -password="$PASSWORD" \
    -url="$JDBC" \
    -locations="filesystem:$FLYWAY_LOCATIONS"

  flyway info migrate info \
    -user="$USERNAME" \
    -password="$PASSWORD" \
    -baselineOnMigrate="true" \
    -locations="filesystem:$FLYWAY_LOCATIONS" \
    -url="$JDBC"
fi

echo "=== Finalizado entrypoint-oracle.sh com sucesso! ==="
echo "Finalizado entrypoint-oracle.sh com sucesso!" >> "$GITHUB_STEP_SUMMARY"
