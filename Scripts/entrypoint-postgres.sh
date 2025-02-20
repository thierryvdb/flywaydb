#!/usr/bin/env bash
set -e

echo "=== ENTRYPOINT POSTGRES (K8s sidecar) ==="

###############################################################################
# 1) Validar variáveis
###############################################################################
if [ -z "$JDBC" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Faltam variáveis essenciais (JDBC, USERNAME, PASSWORD)."
  echo "Faltam variáveis essenciais (JDBC, USERNAME, PASSWORD)." >> "$GITHUB_STEP_SUMMARY"
  exit 1
fi

if [ -z "$REPO_NAME" ]; then
  echo "A variável REPO_NAME não foi definida. Usaremos 'dummy_pg' como fallback."
  echo "A variável REPO_NAME não foi definida. Usaremos 'dummy_pg' como fallback." >> "$GITHUB_STEP_SUMMARY"
  REPO_NAME="dummy_pg"
fi

###############################################################################
# 2) Extrair host/port/db do JDBC
###############################################################################
if [[ "$JDBC" =~ ^jdbc:postgresql://([^:]+):([^/]+)/(.+)$ ]]; then
  PGHOST="${BASH_REMATCH[1]}"
  PGPORT="${BASH_REMATCH[2]}"
  PGDATABASE="${BASH_REMATCH[3]}"
else
  echo "JDBC inválido ou não é PostgreSQL: $JDBC"
  echo "JDBC inválido ou não é PostgreSQL: $JDBC" >> "$GITHUB_STEP_SUMMARY"
  exit 1
fi

echo "PGHOST: $PGHOST"
echo "PGPORT: $PGPORT"
echo "PGDATABASE: $PGDATABASE"
echo "### Postgres Dialect" >> "$GITHUB_STEP_SUMMARY"
echo "Host: $PGHOST" >> "$GITHUB_STEP_SUMMARY"
echo "Port: $PGPORT" >> "$GITHUB_STEP_SUMMARY"
echo "Database: $PGDATABASE" >> "$GITHUB_STEP_SUMMARY"

###############################################################################
# 3) Gerar backup (schema-only)
###############################################################################
echo "Gerando backup schema-only de $PGDATABASE..."
echo "Gerando backup schema-only de $PGDATABASE..." >> "$GITHUB_STEP_SUMMARY"
PGPASSWORD="$PASSWORD" pg_dump \
  -h "$PGHOST" \
  -p "$PGPORT" \
  -U "$USERNAME" \
  --no-owner --no-acl --schema-only \
  --dbname="$PGDATABASE" \
  -F p -b -v \
  -f database.dmp

echo "Backup criado (database.dmp)." >> "$GITHUB_STEP_SUMMARY"

###############################################################################
# 4) Criar Pod sidecar Postgres
###############################################################################
POD_NAME="pg-sidecar-$REPO_NAME"
echo "Criando Pod sidecar Postgres: $POD_NAME" >> "$GITHUB_STEP_SUMMARY"
cat <<EOF > /tmp/$POD_NAME.yaml
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
spec:
  containers:
  - name: postgres
    image: postgres:12
    env:
    - name: POSTGRES_DB
      value: "postgres"
    - name: POSTGRES_USER
      value: "postgres"
    - name: POSTGRES_PASSWORD
      value: "postgres"
    ports:
    - containerPort: 5432
      name: postgres
EOF

kubectl apply -f /tmp/$POD_NAME.yaml

###############################################################################
# 5) Aguardar Running
###############################################################################
while true; do
  STATUS=$(kubectl get pod "$POD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  if [ "$STATUS" == "Running" ]; then
    echo "Pod $POD_NAME está Running."
    echo "Pod $POD_NAME está Running." >> "$GITHUB_STEP_SUMMARY"
    break
  elif [ "$STATUS" == "Failed" ] || [ "$STATUS" == "Succeeded" ] || [ "$STATUS" == "Unknown" ]; then
    echo "Pod $POD_NAME status $STATUS. Abortando."
    echo "Pod $POD_NAME status $STATUS. Abortando." >> "$GITHUB_STEP_SUMMARY"
    exit 1
  else
    echo "Aguardando Pod $POD_NAME (status=$STATUS)..."
    sleep 4
  fi
done

# Esperar Postgres subir
echo "Aguardando PostgreSQL responder pg_isready..." >> "$GITHUB_STEP_SUMMARY"
until kubectl exec "$POD_NAME" -- pg_isready -U postgres; do
  echo "Ainda aguardando..."
  sleep 4
done
echo "Postgres dentro do pod está pronto." >> "$GITHUB_STEP_SUMMARY"

###############################################################################
# 6) Copiar dump e restaurar
###############################################################################
echo "Copiando dump para dentro do Pod..." >> "$GITHUB_STEP_SUMMARY"
kubectl cp database.dmp "$POD_NAME":/tmp/database.dmp

echo "Criando base '$REPO_NAME' no Pod sidecar..." >> "$GITHUB_STEP_SUMMARY"
kubectl exec "$POD_NAME" -- psql -U postgres -c "CREATE DATABASE \"$REPO_NAME\""

echo "Restaurando schema em '$REPO_NAME'..." >> "$GITHUB_STEP_SUMMARY"
kubectl exec "$POD_NAME" -- sh -c "PGPASSWORD=postgres psql -U postgres -d \"$REPO_NAME\" -f /tmp/database.dmp"

###############################################################################
# 7) Criar usuário + permissões
###############################################################################
PG_DUMMY_PASSWORD=$(openssl rand -base64 8 | tr -dc 'A-Za-z0-9' | head -c 8)
kubectl exec "$POD_NAME" -- psql -U postgres -c "CREATE USER $USERNAME WITH PASSWORD '$PG_DUMMY_PASSWORD';"
kubectl exec "$POD_NAME" -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$REPO_NAME\" TO $USERNAME;"

echo "Usuário '$USERNAME' criado com senha '$PG_DUMMY_PASSWORD' no sidecar." >> "$GITHUB_STEP_SUMMARY"

###############################################################################
# 8) Port-forward -> Flyway local
###############################################################################
kubectl port-forward pod/$POD_NAME 15432:5432 &
PORT_FORWARD_PID=$!
echo "Port-forward local 15432 -> $POD_NAME:5432 (PID=$PORT_FORWARD_PID)" >> "$GITHUB_STEP_SUMMARY"
sleep 5

echo "Executando Flyway (clean + migrate) no sidecar Postgres..." >> "$GITHUB_STEP_SUMMARY"
flyway info clean info \
  -user="$USERNAME" \
  -password="$PG_DUMMY_PASSWORD" \
  -baselineOnMigrate="true" \
  -locations="filesystem:$FLYWAY_LOCATIONS" \
  -url="jdbc:postgresql://127.0.0.1:15432/$REPO_NAME" \
  -cleanDisabled=false

flyway info migrate info \
  -user="$USERNAME" \
  -password="$PG_DUMMY_PASSWORD" \
  -baselineOnMigrate="true" \
  -locations="filesystem:$FLYWAY_LOCATIONS" \
  -url="jdbc:postgresql://127.0.0.1:15432/$REPO_NAME"

echo "Encerrando port-forward (PID=$PORT_FORWARD_PID)..." >> "$GITHUB_STEP_SUMMARY"
pkill -f "kubectl port-forward pod/$POD_NAME" || true

###############################################################################
# 9) QA e PROD
###############################################################################
if [ "$RUN_ON_QA" = "true" ] && [ -n "$QA_JDBC" ] && [ -n "$QA_PASSWORD" ]; then
  echo "Rodando Flyway em QA ($QA_JDBC)..." >> "$GITHUB_STEP_SUMMARY"
  flyway -user="$USERNAME" \
         -password="$QA_PASSWORD" \
         -url="$QA_JDBC" \
         -locations="filesystem:$FLYWAY_LOCATIONS" info repair

  flyway info migrate info \
         -user="$USERNAME" \
         -password="$QA_PASSWORD" \
         -baselineOnMigrate="true" \
         -locations="filesystem:$FLYWAY_LOCATIONS" \
         -url="$QA_JDBC"
fi

if [ "$RUN_ON_PROD" = "true" ]; then
  echo "Rodando Flyway em PROD ($JDBC)..." >> "$GITHUB_STEP_SUMMARY"
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

###############################################################################
# 10) Remover Pod
###############################################################################
echo "Removendo Pod $POD_NAME..." >> "$GITHUB_STEP_SUMMARY"
kubectl delete -f /tmp/$POD_NAME.yaml --ignore-not-found=true

echo "=== Finalizado entrypoint-postgres.sh com sucesso! ==="
echo "Finalizado entrypoint-postgres.sh com sucesso!" >> "$GITHUB_STEP_SUMMARY"
