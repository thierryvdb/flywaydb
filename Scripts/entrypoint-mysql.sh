#!/usr/bin/env bash
set -e

echo "=== ENTRYPOINT MYSQL (K8s sidecar) ==="

###############################################################################
# 1) Validar variáveis obrigatórias
###############################################################################
if [ -z "$JDBC" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Faltam variáveis essenciais (JDBC, USERNAME, PASSWORD)."
  echo "Faltam variáveis essenciais (JDBC, USERNAME, PASSWORD)." >> "$GITHUB_STEP_SUMMARY"
  exit 1
fi

if [ -z "$REPO_NAME" ]; then
  echo "A variável REPO_NAME não foi definida. Usaremos 'dummy_mysql' como fallback."
  echo "A variável REPO_NAME não foi definida. Usaremos 'dummy_mysql' como fallback." >> "$GITHUB_STEP_SUMMARY"
  REPO_NAME="dummy_mysql"
fi

###############################################################################
# 2) Extrair HOST/PORT/DB do JDBC
###############################################################################
if [[ "$JDBC" =~ ^jdbc:mysql://([^:]+):([^/]+)/(.+)$ ]]; then
  HOST="${BASH_REMATCH[1]}"
  PORT="${BASH_REMATCH[2]}"
  DATABASE_NAME="${BASH_REMATCH[3]}"
else
  echo "JDBC inválido ou não é MySQL: $JDBC"
  echo "JDBC inválido ou não é MySQL: $JDBC" >> "$GITHUB_STEP_SUMMARY"
  exit 1
fi

echo "HOST: $HOST"
echo "PORT: $PORT"
echo "DATABASE_NAME: $DATABASE_NAME"
echo "### MySQL Dialect" >> "$GITHUB_STEP_SUMMARY"
echo "Host: $HOST" >> "$GITHUB_STEP_SUMMARY"
echo "Port: $PORT" >> "$GITHUB_STEP_SUMMARY"
echo "Database Name: $DATABASE_NAME" >> "$GITHUB_STEP_SUMMARY"

###############################################################################
# 3) Gerar backup local (schema-only) da base real
###############################################################################
echo "Gerando backup (schema only) da base real..."
echo "Gerando backup (schema only) da base real..." >> "$GITHUB_STEP_SUMMARY"

mysqldump \
  -h "$HOST" \
  -P "$PORT" \
  -u "$USERNAME" \
  -p"$PASSWORD" \
  --no-data --databases "$DATABASE_NAME" \
  --no-tablespaces \
  > database.dmp

echo "Backup criado (database.dmp)." >> "$GITHUB_STEP_SUMMARY"

###############################################################################
# 4) Criar Pod sidecar MySQL
###############################################################################
POD_NAME="mysql-sidecar-$REPO_NAME"
echo "Criando Pod sidecar MySQL: $POD_NAME" >> "$GITHUB_STEP_SUMMARY"
cat <<EOF > /tmp/$POD_NAME.yaml
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
spec:
  containers:
  - name: mysql
    image: mysql:8
    env:
    - name: MYSQL_ALLOW_EMPTY_PASSWORD
      value: "yes"
    ports:
    - containerPort: 3306
      name: mysql
EOF

kubectl apply -f /tmp/$POD_NAME.yaml

###############################################################################
# 5) Aguardar o Pod ficar Running
###############################################################################
while true; do
  STATUS=$(kubectl get pod "$POD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  if [ "$STATUS" == "Running" ]; then
    echo "Pod $POD_NAME está em Running"
    echo "Pod $POD_NAME está em Running" >> "$GITHUB_STEP_SUMMARY"
    break
  elif [ "$STATUS" == "Failed" ] || [ "$STATUS" == "Succeeded" ] || [ "$STATUS" == "Unknown" ]; then
    echo "Pod $POD_NAME status $STATUS. Abortando."
    echo "Pod $POD_NAME status $STATUS. Abortando." >> "$GITHUB_STEP_SUMMARY"
    exit 1
  else
    echo "Aguardando Pod $POD_NAME (status=$STATUS)..."
    sleep 5
  fi
done

###############################################################################
# 6) Esperar MySQL ficar pronto (mysqladmin ping)
###############################################################################
echo "Aguardando MySQL responder mysqladmin ping..."
echo "Aguardando MySQL responder mysqladmin ping..." >> "$GITHUB_STEP_SUMMARY"

until kubectl exec "$POD_NAME" -- mysqladmin ping --silent; do
  echo "Ainda aguardando..."
  sleep 4
done

echo "MySQL dentro do Pod está pronto para conexões." >> "$GITHUB_STEP_SUMMARY"

###############################################################################
# 7) Copiar dump e restaurar
###############################################################################
echo "Copiando dump para dentro do pod..." >> "$GITHUB_STEP_SUMMARY"
kubectl cp database.dmp "$POD_NAME":/tmp/database.dmp

echo "Restaurando dump no sidecar MySQL..." >> "$GITHUB_STEP_SUMMARY"
kubectl exec "$POD_NAME" -- sh -c "mysql -uroot -e 'source /tmp/database.dmp;'"

###############################################################################
# 8) Criar usuário e permissões
###############################################################################
MYSQL_USER_PASSWORD=$(openssl rand -base64 8 | tr -dc 'A-Za-z0-9' | head -c 8)
kubectl exec "$POD_NAME" -- \
  mysql -uroot -e "CREATE USER '$USERNAME'@'%' IDENTIFIED BY '$MYSQL_USER_PASSWORD'; \
                   GRANT ALL PRIVILEGES ON \`$DATABASE_NAME\`.* TO '$USERNAME'@'%'; \
                   FLUSH PRIVILEGES;"

echo "Usuário '$USERNAME' criado com senha '$MYSQL_USER_PASSWORD' no sidecar." >> "$GITHUB_STEP_SUMMARY"

###############################################################################
# 9) Port-forward e rodar Flyway local
###############################################################################
kubectl port-forward pod/$POD_NAME 13306:3306 &
PORT_FORWARD_PID=$!
echo "Port-forward local 13306 -> $POD_NAME:3306 (PID=$PORT_FORWARD_PID)" >> "$GITHUB_STEP_SUMMARY"
sleep 5

echo "Executando Flyway (clean + migrate) no sidecar..." >> "$GITHUB_STEP_SUMMARY"
flyway info clean info \
  -user="$USERNAME" \
  -password="$MYSQL_USER_PASSWORD" \
  -baselineOnMigrate="true" \
  -locations="filesystem:$FLYWAY_LOCATIONS" \
  -url="jdbc:mysql://127.0.0.1:13306/$DATABASE_NAME?useSSL=false&allowPublicKeyRetrieval=true" \
  -cleanDisabled=false

flyway info migrate info \
  -user="$USERNAME" \
  -password="$MYSQL_USER_PASSWORD" \
  -baselineOnMigrate="true" \
  -locations="filesystem:$FLYWAY_LOCATIONS" \
  -url="jdbc:mysql://127.0.0.1:13306/$DATABASE_NAME?useSSL=false&allowPublicKeyRetrieval=true"

echo "Encerrando port-forward (PID=$PORT_FORWARD_PID)..." >> "$GITHUB_STEP_SUMMARY"
pkill -f "kubectl port-forward pod/$POD_NAME" || true

###############################################################################
# 10) Flyway em QA e PROD
###############################################################################
if [ "$RUN_ON_QA" = "true" ] && [ -n "$QA_JDBC" ] && [ -n "$QA_PASSWORD" ]; then
  echo "Rodando Flyway em QA ($QA_JDBC)..." >> "$GITHUB_STEP_SUMMARY"
  flyway -user="$USERNAME" \
         -password="$QA_PASSWORD" \
         -url="$QA_JDBC?useSSL=false&allowPublicKeyRetrieval=true" \
         -locations="filesystem:$FLYWAY_LOCATIONS" info repair

  flyway info migrate info \
         -user="$USERNAME" \
         -password="$QA_PASSWORD" \
         -baselineOnMigrate="true" \
         -locations="filesystem:$FLYWAY_LOCATIONS" \
         -url="$QA_JDBC?useSSL=false&allowPublicKeyRetrieval=true"
fi

if [ "$RUN_ON_PROD" = "true" ]; then
  echo "Rodando Flyway em PROD ($JDBC)..." >> "$GITHUB_STEP_SUMMARY"
  flyway info repair \
    -user="$USERNAME" \
    -password="$PASSWORD" \
    -url="$JDBC?useSSL=false&allowPublicKeyRetrieval=true" \
    -locations="filesystem:$FLYWAY_LOCATIONS"

  flyway info migrate info \
    -user="$USERNAME" \
    -password="$PASSWORD" \
    -baselineOnMigrate="true" \
    -locations="filesystem:$FLYWAY_LOCATIONS" \
    -url="$JDBC?useSSL=false&allowPublicKeyRetrieval=true"
fi

###############################################################################
# 11) Remover Pod sidecar
###############################################################################
echo "Removendo Pod sidecar: $POD_NAME" >> "$GITHUB_STEP_SUMMARY"
kubectl delete -f /tmp/$POD_NAME.yaml --ignore-not-found=true

echo "=== Finalizado entrypoint-mysql.sh com sucesso! ==="
echo "Finalizado entrypoint-mysql.sh com sucesso!" >> "$GITHUB_STEP_SUMMARY"
