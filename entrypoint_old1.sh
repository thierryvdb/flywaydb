#!/bin/bash
# entrypoint.sh
# Created by thierry.p.broucke@altice.pt

set -e

# First argument is the GITHUB_STEP_SUMMARY path
GITHUB_STEP_SUMMARY="$1"

# Second argument is the GITHUB_WORKSPACE
GITHUB_WORKSPACE="$2"

# Assign inputs to variables (environment variables)
DATABASE="${DATABASE}"
JDBC="${JDBC}"
PASSWORD="${PASSWORD}"
USERNAME="${USERNAME}"
SCHEMAS="${SCHEMAS}"
DIALECT="${DIALECT}"
REPO_NAME="${REPO_NAME}"
ROOT_PASSWORD="${ROOT_PASSWORD}"
FLYWAY_LOCATIONS="${FLYWAY_LOCATIONS}"
FLYWAY_USER="${FLYWAY_USER}"
FLYWAY_PASSWORD="${FLYWAY_PASSWORD}"

# Debugging statements to check if variables are set
echo "DATABASE: $DATABASE"
echo "JDBC: $JDBC"
echo "PASSWORD: [REDACTED]"
echo "USERNAME: $USERNAME"
echo "SCHEMAS: $SCHEMAS"
echo "DIALECT: $DIALECT"
echo "REPO_NAME: $REPO_NAME"
echo "ROOT_PASSWORD: [REDACTED]"
echo "FLYWAY_LOCATIONS: $FLYWAY_LOCATIONS"
echo "FLYWAY_USER: $FLYWAY_USER"
echo "FLYWAY_PASSWORD: [REDACTED]"
echo "GITHUB_WORKSPACE: $GITHUB_WORKSPACE"

# Function to check if a secret is set
check_secret() {
  if [ -z "$1" ]; then
    echo "The '$2' secret is not set. Please set it in your repository settings."
    echo "😤 The variable '$2' is missing." >> "$GITHUB_STEP_SUMMARY"
    exit 1
  else
    echo "$2 Secret :green_circle: " >> "$GITHUB_STEP_SUMMARY"
  fi
}

# Check necessary secrets
check_secret "$DATABASE" "DATABASE"
check_secret "$JDBC" "JDBC"
check_secret "$PASSWORD" "PASSWORD"
check_secret "$USERNAME" "USERNAME"
check_secret "$DIALECT" "DIALECT"
check_secret "$REPO_NAME" "REPO_NAME"
check_secret "$ROOT_PASSWORD" "ROOT_PASSWORD"
check_secret "$FLYWAY_LOCATIONS" "FLYWAY_LOCATIONS"
check_secret "$FLYWAY_USER" "FLYWAY_USER"
check_secret "$FLYWAY_PASSWORD" "FLYWAY_PASSWORD"

# Function to extract values from JDBC URL
extract_jdbc_values() {
  PROTOCOL=$(echo "$JDBC" | sed -n 's#^\(.*\):\/\/.*#\1#p')
  HOST=$(echo "$JDBC" | sed -n 's#.*://\([^:/]*\).*#\1#p')
  PORT=$(echo "$JDBC" | sed -n 's#.*:\([0-9]*\)/.*#\1#p')
  DATABASE_NAME=$(echo "$JDBC" | sed -n 's#.*/\([^?]*\).*#\1#p')

  echo "Connection: $PROTOCOL" >> "$GITHUB_STEP_SUMMARY"
  echo "Host: $HOST" >> "$GITHUB_STEP_SUMMARY"
  echo "Port: $PORT" >> "$GITHUB_STEP_SUMMARY"
  echo "Database: $DATABASE_NAME" >> "$GITHUB_STEP_SUMMARY"
}

# Extract JDBC values
extract_jdbc_values

echo "✋" >> "$GITHUB_STEP_SUMMARY"
echo "Checking connection to Database $DATABASE" >> "$GITHUB_STEP_SUMMARY"

# Function to connect to the database
connect_to_database() {
  if [ "$DIALECT" = "mysql" ]; then
    RESULT=$(mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" "$DATABASE_NAME" -s --skip-column-names -e "SELECT 1;")
    if [ "$RESULT" == "1" ]; then
      echo "Connection Successful :green_circle: " >> "$GITHUB_STEP_SUMMARY"
    else
      echo "Connection Failed :red_circle: " >> "$GITHUB_STEP_SUMMARY"
      exit 1
    fi
  elif [ "$DIALECT" = "postgresql" ]; then
    RESULT=$(PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$DATABASE_NAME" -c "SELECT 1;" -tA)
    if [[ "$RESULT" == "1" ]]; then
      echo "Connection Successful :green_circle: " >> "$GITHUB_STEP_SUMMARY"
    else
      echo "Connection Failed :red_circle: " >> "$GITHUB_STEP_SUMMARY"
      exit 1
    fi
  else
    echo "Unsupported dialect: $DIALECT" >> "$GITHUB_STEP_SUMMARY"
    exit 1
  fi
}

# Connect to the database
connect_to_database

echo "✋" >> "$GITHUB_STEP_SUMMARY"
echo "Getting the database version" >> "$GITHUB_STEP_SUMMARY"

# Function to get the database version
get_database_version() {
  if [ "$DIALECT" = "mysql" ]; then
    version=$(mysql -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" -D "$DATABASE_NAME" -s --skip-column-names -e "SELECT VERSION();")
    echo "DBVERSION=$version" >> "$GITHUB_OUTPUT"
    echo "🐬 $DIALECT Version: $version" >> "$GITHUB_STEP_SUMMARY"
  elif [ "$DIALECT" = "postgresql" ]; then
    version=$(PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$DATABASE_NAME" -c "SHOW server_version;" -tA)
    echo "DBVERSION=$version" >> "$GITHUB_OUTPUT"
    echo "🐘 $DIALECT Version: $version" >> "$GITHUB_STEP_SUMMARY"
  fi
}

# Get the database version
get_database_version

echo "✋" >> "$GITHUB_STEP_SUMMARY"
echo "Generating a metadata backup" >> "$GITHUB_STEP_SUMMARY"

# Function to generate a database backup
generate_backup() {
  if [ "$DIALECT" = "mysql" ]; then
    mysqldump -h "$HOST" -P "$PORT" -u "$USERNAME" -p"$PASSWORD" --no-data --databases "$DATABASE_NAME" --ignore-table="$DATABASE_NAME.flyway_schema_history" --no-tablespaces > database.dmp
    echo "Backup created: database.dmp" >> "$GITHUB_STEP_SUMMARY"
    ls -al database.dmp >> "$GITHUB_STEP_SUMMARY"
  elif [ "$DIALECT" = "postgresql" ]; then
    PGPASSWORD="$PASSWORD" pg_dump -h "$HOST" -p "$PORT" -U "$USERNAME" --no-owner --no-acl --schema-only --dbname="$DATABASE_NAME" --exclude-table=flyway_schema_history -F c -b -v -f database.dmp
    echo "Backup created: database.dmp" >> "$GITHUB_STEP_SUMMARY"
    ls -al database.dmp >> "$GITHUB_STEP_SUMMARY"
  fi
}

# Generate a backup
generate_backup

echo "✋" >> "$GITHUB_STEP_SUMMARY"
echo "Creating the dummy Database" >> "$GITHUB_STEP_SUMMARY"

create_dummy_db() {
  if [ "$DIALECT" = "mysql" ]; then
    # Run the MySQL container using Podman
    podman run --name "$REPO_NAME" -e MYSQL_ROOT_PASSWORD="$ROOT_PASSWORD" -d -p 3307:3306 mysql:latest
    echo "MySQL container '$REPO_NAME' created successfully with root password." >> "$GITHUB_STEP_SUMMARY"
    
    # Wait for MySQL to initialize
    until podman exec "$REPO_NAME" mysqladmin ping --silent; do
      echo "Waiting for MySQL to start..."
      sleep 2
    done

    # Create the database
    podman exec "$REPO_NAME" mysql -uroot -p"$ROOT_PASSWORD" -e "CREATE DATABASE $REPO_NAME;"
    echo "Database '$REPO_NAME' created in MySQL container." >> "$GITHUB_STEP_SUMMARY"

  elif [ "$DIALECT" = "postgresql" ]; then
    # Run the PostgreSQL container using Podman
    podman run --name "$REPO_NAME" -e POSTGRES_PASSWORD="$ROOT_PASSWORD" -e POSTGRES_USER="admin" -d -p 5433:5432 postgres:latest
    echo "PostgreSQL container '$REPO_NAME' created successfully with admin password." >> "$GITHUB_STEP_SUMMARY"

    # Wait for PostgreSQL to initialize
    until podman exec "$REPO_NAME" pg_isready -U admin; do
      echo "Waiting for PostgreSQL to start..."
      sleep 2
    done

    # Create the database
    podman exec "$REPO_NAME" psql -U admin -c "CREATE DATABASE \"$REPO_NAME\";"
    echo "Database '$REPO_NAME' created in PostgreSQL container." >> "$GITHUB_STEP_SUMMARY"

  else
    echo "Unsupported dialect for creating dummy database: $DIALECT" >> "$GITHUB_STEP_SUMMARY"
    exit 1
  fi
}

create_dummy_db

echo "✋" >> "$GITHUB_STEP_SUMMARY"
echo "Restoring to the database version" >> "$GITHUB_STEP_SUMMARY"

# Function to restore the database to a dummy environment
restore_to_dummy() {
  if [ "$DIALECT" = "mysql" ]; then
    podman cp database.dmp "$REPO_NAME":/database.dmp
    podman exec "$REPO_NAME" mysql -uroot -p"$ROOT_PASSWORD" "$REPO_NAME" < /database.dmp
    echo "Database restored successfully" >> "$GITHUB_STEP_SUMMARY"
  elif [ "$DIALECT" = "postgresql" ]; then
    podman cp database.dmp "$REPO_NAME":/database.dmp
    podman exec "$REPO_NAME" sh -c "PGPASSWORD=$ROOT_PASSWORD pg_restore --no-owner -U admin -d \"$REPO_NAME\" -v /database.dmp"
    echo "Database restored successfully" >> "$GITHUB_STEP_SUMMARY"
  fi
}

# Restore to dummy environment
restore_to_dummy

echo "✋" >> "$GITHUB_STEP_SUMMARY"
echo "Authenticating with Flyway" >> "$GITHUB_STEP_SUMMARY"

# Function to authenticate with Flyway
flyway_authenticate() {
  flyway -user="$FLYWAY_USER" -password="$FLYWAY_PASSWORD" -url="$JDBC" info
  echo "Flyway authenticated successfully" >> "$GITHUB_STEP_SUMMARY"
}

# Authenticate with Flyway
flyway_authenticate

echo "✋" >> "$GITHUB_STEP_SUMMARY"
echo "Running Flyway migrations and generating report" >> "$GITHUB_STEP_SUMMARY"

# Function to run Flyway migrations and generate an HTML report
run_flyway_migrations_with_report() {
  FLYWAY_OUTPUT_FILE=$(mktemp)
  flyway -user="$USERNAME" -password="$PASSWORD" -baselineOnMigrate="true" -locations="filesystem:$GITHUB_WORKSPACE/$FLYWAY_LOCATIONS" migrate info -url="jdbc:$DIALECT://localhost:$PORT/$REPO_NAME" -cleanDisabled='false' | tee "$FLYWAY_OUTPUT_FILE"
  echo ":rocket:" >> "$GITHUB_STEP_SUMMARY"
  
  RESULT=$(cat "$FLYWAY_OUTPUT_FILE" | sed '/+-----------+-------------+-------------+------+---------------------+---------+----------+/d' | grep "Schema version" -A9999 | tail -n +3 )
  
  html_table=$(echo "$RESULT" | awk 'BEGIN {
    FS="|";
    print "<table>";
    print "<tr><th>Category</th><th>Version</th><th>Description</th><th>Type</th><th>Installed On</th><th>State</th><th>Undoable</th></tr>"
  }
  NR>2 && NF {
    gsub(/^ +| +$/,"",$2);
    gsub(/^ +| +$/,"",$3);
    gsub(/^ +| +$/,"",$4);
    gsub(/^ +| +$/,"",$5);
    gsub(/^ +| +$/,"",$6);
    gsub(/^ +| +$/,"",$7);
    state = $7;
    if (state == "Success") {
      state = state " :green_circle: ";
    }
    else 
      state = state " :red_circle: " 
    gsub(/^ +| +$/,"",$8);
    print "<tr><td>"$2"</td><td>"$3"</td><td>"$4"</td><td>"$5"</td><td>"$6"</td><td>"state"</td><td>"$8"</td></tr>"
  }
  END {
    print "</table>"
  }')
  echo "$html_table" >> "$GITHUB_STEP_SUMMARY"
}

# Run Flyway migrations and generate an HTML report
run_flyway_migrations_with_report

echo "Finish" >> "$GITHUB_STEP_SUMMARY"
