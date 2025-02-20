#!/bin/bash
#Created by thierry.p.broucke@altice.pt

set -e

# Assign inputs to variables
DATABASE=${DATABASE}
JDBC=${JDBC}
PASSWORD=${PASSWORD}
USERNAME=${USERNAME}
SCHEMAS=${SCHEMAS}
DIALECT=${DIALECT}
REPO_NAME=${REPO_NAME}
ROOT_PASSWORD=${ROOT_PASSWORD}
FLYWAY_LOCATIONS=${FLYWAY_LOCATIONS}
FLYWAY_USER=${FLYWAY_USER}
FLYWAY_PASSWORD=${FLYWAY_PASSWORD}

# Debugging statements to check if variables are set
echo "DATABASE: $DATABASE"
echo "JDBC: $JDBC"
echo "PASSWORD: $PASSWORD"
echo "USERNAME: $USERNAME"
echo "SCHEMAS: $SCHEMAS"
echo "DIALECT: $DIALECT"
echo "REPO_NAME: $REPO_NAME"
echo "ROOT_PASSWORD: $ROOT_PASSWORD"
echo "FLYWAY_LOCATIONS: $FLYWAY_LOCATIONS"
echo "FLYWAY_USER: $FLYWAY_USER"
echo "FLYWAY_PASSWORD: $FLYWAY_PASSWORD"

# Function to check if a secret is set
check_secret() {
  if [ -z "$1" ]; then
    echo "The '$2' secret is not set. Please set it in your repository settings."
    echo "😤 The variable '$2' is missing." >> $GITHUB_STEP_SUMMARY
    exit 1
  else
    echo "$2 Secret :green_circle: " >> $GITHUB_STEP_SUMMARY
  fi
}

# Check necessary secrets
check_secret "$DATABASE" "DATABASE CHECK"
check_secret "$JDBC" "JDBC CHECK"
check_secret "$PASSWORD" "PASSWORD CHECK"
check_secret "$USERNAME" "USERNAME CHECK"
check_secret "$SCHEMAS" "SCHEMAS CHECK"
check_secret "$FLYWAY_USER" "FLYWAY_USER CHECK"
check_secret "$FLYWAY_PASSWORD" "FLYWAY_PASSWORD CHECK"

# Function to extract values from JDBC URL
extract_jdbc_values() {
  PROTOCOL=$(echo "$JDBC" | sed 's/\(.*\):\(.*\)/\1/')
  HOST=$(echo "$JDBC" | sed 's/.*\/\/\([^:]*\).*/\1/')
  PORT=$(echo "$JDBC" | sed 's/.*:\([^\/]*\).*/\1/')
  DATABASE_NAME=$(echo "$JDBC" | sed 's/.*\/\([^\/]*\)/\1/')

  echo "Connection: $PROTOCOL" >> $GITHUB_STEP_SUMMARY
  echo "Host: $HOST" >> $GITHUB_STEP_SUMMARY
  echo "Port: $PORT" >> $GITHUB_STEP_SUMMARY
  echo "Database: $DATABASE_NAME" >> $GITHUB_STEP_SUMMARY
}

# Extract JDBC values
extract_jdbc_values

echo "✋" >> $GITHUB_STEP_SUMMARY
echo "Checking connection to Database $DATABASE" >> $GITHUB_STEP_SUMMARY
# Function to connect to the database
connect_to_database() {
  if [ "$DIALECT" = "mysql" ]; then
    RESULT=$(mysql -h "$HOST" -u "$USERNAME" -p"$PASSWORD" "$DATABASE" -s --skip-column-names -e "SELECT 1;")
    if [ "$RESULT" == "1" ]; then
      echo "Connection Successful :green_circle: " >> $GITHUB_STEP_SUMMARY
    else
      echo "Connection Failed :red_circle: " >> $GITHUB_STEP_SUMMARY
      exit 1
    fi
  elif [ "$DIALECT" = "postgresql" ]; then
    RESULT=$(PGPASSWORD="$PASSWORD" psql -h "$HOST" -U "$USERNAME" -d "$DATABASE" -c "SELECT 1;" -tA)
    if [[ "$RESULT" == *"1"* ]]; then
      echo "Connection Successful :green_circle: " >> $GITHUB_STEP_SUMMARY
    else
      echo "Connection Failed :red_circle: " >> $GITHUB_STEP_SUMMARY
      exit 1
    fi
  elif [ "$DIALECT" = "oracle" ]; then
    echo "- Selected dialect is ⭕ $DIALECT " >> $GITHUB_STEP_SUMMARY
  elif [ "$DIALECT" = "sqlserver" ]; then
    echo "- Selected dialect is 🪟 $DIALECT " >> $GITHUB_STEP_SUMMARY
  else
    echo "- Selected dialect is ❓ $DIALECT " >> $GITHUB_STEP_SUMMARY
  fi
}

# Connect to the database
connect_to_database


echo "✋" >> $GITHUB_STEP_SUMMARY
echo "Getting the database version" >> $GITHUB_STEP_SUMMARY
# Function to get the database version
get_database_version() {
  if [ "$DIALECT" = "mysql" ]; then
    version=$(mysql -h "$HOST" -u "$USERNAME" -p"$PASSWORD" -D "$DATABASE" -s --skip-column-names -e "SELECT VERSION();")
    echo "DBVERSION=$version" >> $GITHUB_OUTPUT
    echo "🐬 $DIALECT Version : $version " >> $GITHUB_STEP_SUMMARY
  elif [ "$DIALECT" = "postgresql" ]; then
    version=$(PGPASSWORD="$PASSWORD" psql -h "$HOST" -U "$USERNAME" -d "$DATABASE" -c "SHOW server_version;" -tA)
    echo "DBVERSION=$version" >> $GITHUB_OUTPUT
    echo "🐘 $DIALECT Version : $version" >> $GITHUB_STEP_SUMMARY
  elif [ "$DIALECT" = "oracle" ]; then
    echo "- Selected dialect is ⭕ $DIALECT " >> $GITHUB_STEP_SUMMARY
  elif [ "$DIALECT" = "sqlserver" ]; then
    echo "- Selected dialect is 🪟 $DIALECT " >> $GITHUB_STEP_SUMMARY
  else
    echo "- Selected dialect is ❓ $DIALECT " >> $GITHUB_STEP_SUMMARY
  fi
}

# Get the database version
get_database_version


echo "✋" >> $GITHUB_STEP_SUMMARY
echo "Generating a metadata backup" >> $GITHUB_STEP_SUMMARY
# Function to generate a database backup
generate_backup() {
  if [ "$DIALECT" = "mysql" ]; then
    /usr/bin/mysqldump -h "$HOST" -u "$USERNAME" -p"$PASSWORD" --no-data --databases "$DATABASE" --ignore-table="$DATABASE".flyway_schema_history --no-tablespaces > database.dmp
    echo "Backup created: database.dmp" >> $GITHUB_STEP_SUMMARY
    ls -al database.dmp >> $GITHUB_STEP_SUMMARY
  elif [ "$DIALECT" = "postgresql" ]; then
    /usr/bin/pg_dump -h "$HOST" -U "$USERNAME" --no-owner --no-acl --schema-only --dbname="$DATABASE" --exclude-table=flyway_schema_history -F c -b -v -f database.dmp
    echo "Backup created: database.dmp" >> $GITHUB_STEP_SUMMARY
    ls -al database.dmp >> $GITHUB_STEP_SUMMARY
  elif [ "$DIALECT" = "oracle" ]; then
    echo "- Selected dialect is ⭕ $DIALECT " >> $GITHUB_STEP_SUMMARY
  elif [ "$DIALECT" = "sqlserver" ]; then
    echo "- Selected dialect is 🪟 $DIALECT " >> $GITHUB_STEP_SUMMARY
  else
    echo "- Selected dialect is ❓ $DIALECT " >> $GITHUB_STEP_SUMMARY
  fi
}

# Generate a backup
generate_backup

echo "✋" >> $GITHUB_STEP_SUMMARY
echo "Creating the dummy Database" >> $GITHUB_STEP_SUMMARY
create_dummy_db() {
  if [ "$DIALECT" = "mysql" ]; then
    # Run the MySQL container
    podman run --name "$REPO_NAME" -e MYSQL_ROOT_PASSWORD="$ROOT_PASSWORD" -d mysql:latest
    echo "MySQL container '$REPO_NAME' created successfully with root password." >> $GITHUB_STEP_SUMMARY
    
    # Wait for MySQL to initialize
    until podman exec "$REPO_NAME" mysqladmin ping --silent; do
      echo "Waiting for MySQL to start..."
      sleep 2
    done

    # Create the database
    podman exec "$REPO_NAME" mysql -uroot -p"$ROOT_PASSWORD" -e "CREATE DATABASE $REPO_NAME;"
    echo "Database '$REPO_NAME' created in MySQL container." >> $GITHUB_STEP_SUMMARY

  elif [ "$DIALECT" = "postgresql" ]; then
    # Run the PostgreSQL container
    podman run --name "$REPO_NAME" -e POSTGRES_PASSWORD="$ROOT_PASSWORD" -e POSTGRES_USER="admin" -d postgres:latest
    echo "PostgreSQL container '$REPO_NAME' created successfully with admin password." >> $GITHUB_STEP_SUMMARY

    # Wait for PostgreSQL to initialize
    until podman exec "$REPO_NAME" pg_isready -U admin; do
      echo "Waiting for PostgreSQL to start..."
      sleep 2
    done

    # Create the database
    podman exec "$REPO_NAME" psql -U admin -c "CREATE DATABASE \"$REPO_NAME\";"
    echo "Database '$REPO_NAME' created in PostgreSQL container." >> $GITHUB_STEP_SUMMARY

  else
    echo "Unsupported dialect for creating dummy database: $DIALECT" >> $GITHUB_STEP_SUMMARY
    exit 1
  fi
}

create_dummy_db

echo "✋" >> $GITHUB_STEP_SUMMARY
echo "Restoring to the database version" >> $GITHUB_STEP_SUMMARY
# Function to restore the database to a dummy environment
restore_to_dummy() {
  if [ "$DIALECT" = "mysql" ]; then
    podman exec -i "$REPO_NAME" mysql -u root -p"$ROOT_PASSWORD" < database.dmp
    echo "Database restored successfully" >> $GITHUB_STEP_SUMMARY
  elif [ "$DIALECT" = "postgresql" ]; then
    podman cp database.dmp "$REPO_NAME":/database.dmp
    podman exec -i "$REPO_NAME" sh -c "PGPASSWORD=$PASSWORD pg_restore --no-owner -U $USERNAME -d $DATABASE -v /database.dmp"
    echo "Database restored successfully" >> $GITHUB_STEP_SUMMARY
  elif [ "$DIALECT" = "oracle" ]; then
    echo "- Selected dialect is ⭕ $DIALECT " >> $GITHUB_STEP_SUMMARY
  elif [ "$DIALECT" = "sqlserver" ]; then
    echo "- Selected dialect is 🪟 $DIALECT " >> $GITHUB_STEP_SUMMARY
  else
    echo "- Selected dialect is ❓ $DIALECT " >> $GITHUB_STEP_SUMMARY
  fi
}

# Restore to dummy environment
restore_to_dummy

# Function to authenticate with Flyway
flyway_authenticate() {
  /opt/flyway/flyway auth -user="$FLYWAY_USER" -password="$FLYWAY_PASSWORD" -logout
  echo "Flyway authenticated successfully" >> $GITHUB_STEP_SUMMARY
}

# Authenticate with Flyway
flyway_authenticate

# Function to run Flyway migrations and generate an HTML report
run_flyway_migrations_with_report() {
  FLYWAY_OUTPUT_FILE=$(mktemp)
  eval /opt/flyway/flyway -user="$USERNAME" -password="$PASSWORD" -baselineOnMigrate="true" -configFiles="flyway.toml" -locations="filesystem:$FLYWAY_LOCATIONS" info migrate info -url="$JDBC" -cleanDisabled='false' | tee "$FLYWAY_OUTPUT_FILE"
  echo ":rocket:" >> $GITHUB_STEP_SUMMARY
  RESULT=$(cat $FLYWAY_OUTPUT_FILE | sed '/+-----------+-------------+-------------+------+---------------------+---------+----------+/d' | grep "Schema version" -A9999 | tail -n +3 )
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
  echo "$html_table" >> $GITHUB_STEP_SUMMARY
}

# Run Flyway migrations and generate an HTML report
run_flyway_migrations_with_report

echo "Finish"
