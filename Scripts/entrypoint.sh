#!/usr/bin/env bash

set -e

# Mapeie os argumentos
DATABASE="$1"
JDBC="$2"
PASSWORD="$3"
USERNAME="$4"
QA_JDBC="$5"
QA_PASSWORD="$6"
SCHEMAS="$7"
DIALECT="$8"
REPO_NAME="$9"
ROOT_PASSWORD="${10}"
FLYWAY_LOCATIONS="${11}"
FLYWAY_USER="${12}"
FLYWAY_PASSWORD="${13}"
FLYWAY_CLI_INSTALL_CHECK="${14}"
FLYWAY_VERSION="${15}"
FLYWAY_INSTALL_DIRECTORY="${16}"
OCI_TARGET_TDE_WALLET_ID="${17}"
OCI_TARGET_CID="${18}"
OCI_CLI_USER="${19}"
OCI_CLI_TENANCY="${20}"
OCI_CLI_REGION="${21}"
OCI_CLI_FINGERPRINT="${22}"
OCI_CLI_KEY_CONTENT="${23}"
OCI_PDB_ID="${24}"
OCI_SOURCE_QCARBON_KEY="${25}"
OCI_CDB_ID="${26}"
RUN_ON_PROD="${27}"
RUN_ON_QA="${28}"

# Exporte variáveis de ambiente para o script específico conseguir enxergar
export DATABASE JDBC PASSWORD USERNAME QA_JDBC QA_PASSWORD SCHEMAS DIALECT REPO_NAME ROOT_PASSWORD
export FLYWAY_LOCATIONS FLYWAY_USER FLYWAY_PASSWORD FLYWAY_CLI_INSTALL_CHECK FLYWAY_VERSION FLYWAY_INSTALL_DIRECTORY
export OCI_TARGET_TDE_WALLET_ID OCI_TARGET_CID OCI_CLI_USER OCI_CLI_TENANCY OCI_CLI_REGION OCI_CLI_FINGERPRINT OCI_CLI_KEY_CONTENT
export OCI_PDB_ID OCI_SOURCE_QCARBON_KEY OCI_CDB_ID RUN_ON_PROD RUN_ON_QA

echo "=== ENTRYPOINT PRINCIPAL ==="
echo "DATABASE: $DATABASE"
echo "JDBC: $JDBC"
echo "DIALECT: $DIALECT"
echo "REPO_NAME: $REPO_NAME"
echo "RUN_ON_PROD: $RUN_ON_PROD"
echo "RUN_ON_QA: $RUN_ON_QA"

# Aqui roteamos para o script correto
case "$DIALECT" in
  mysql)
    echo "Chamando entrypoint-mysql.sh ..."
    /Scripts/entrypoint-mysql.sh
    ;;
  postgresql|postgres)
    echo "Chamando entrypoint-postgres.sh ..."
    /Scripts/entrypoint-postgres.sh
    ;;
  oracle)
    echo "Chamando entrypoint-oracle.sh ..."
    /Scripts/entrypoint-oracle.sh
    ;;
  *)
    echo "Erro: DIALECT não suportado. Use 'mysql', 'postgresql' ou 'oracle'."
    exit 1
    ;;
esac
