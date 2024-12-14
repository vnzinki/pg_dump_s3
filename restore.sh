#!/bin/bash

# Load environment variables from a .env file (if using one)
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Ensure all required environment variables are set
REQUIRED_VARS="PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY S3_BUCKET S3_PATH"

# Check if each required variable is set
for var in $REQUIRED_VARS; do
  if [ -z "$(eval echo \$$var)" ]; then
    echo "Error: Environment variable $var is not set."
    exit 1
  fi
done

# Require the backup file name as input
if [ -z "$1" ]; then
  echo "Usage: $0 <backup-file-name>"
  echo "Example: $0 mydatabase_dump_2024-12-14_15-30-45.sql"
  exit 1
fi

BACKUP_FILE=$1
REMOTE_BACKUPFILE="s3://$S3_BUCKET/$S3_PATH/$BACKUP_FILE"

# Define the local file path for the downloaded backup
LOCAL_FILE="restore_$BACKUP_FILE"

# Download the backup file from S3
echo "Downloading $BACKUP_FILE from S3..."
aws s3 cp s3://$S3_BUCKET/$S3_PATH/$BACKUP_FILE $BACKUP_FILE

if [ $? -eq 0 ]; then
  echo "Successfully downloaded $REMOTE_BACKUPFILE to $BACKUP_FILE"
else
  echo "Failed to download $REMOTE_BACKUPFILE"
  exit 1
fi

# Export PGPASSWORD to avoid password prompt
export PGPASSWORD=$PGPASSWORD

# Check if the database exists
DB_EXISTS=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -tAc "SELECT 1 FROM pg_database WHERE datname = '$PGDATABASE';")

if [ "$DB_EXISTS" != "1" ]; then
  echo "Database $PGDATABASE does not exist. Creating it..."
  createdb -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$PGDATABASE"
  if [ $? -ne 0 ]; then
    echo "Failed to create database $PGDATABASE"
    exit 1
  fi
  echo "Database $PGDATABASE created successfully"
else
  echo "Database $PGDATABASE already exists"
fi

# Restore the database from the backup
echo "Restoring database $PGDATABASE from $BACKUP_FILE..."
pg_restore -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -v -O --clean -x $BACKUP_FILE

if [ $? -eq 0 ]; then
  echo "Database $PGDATABASE restored successfully from $BACKUP_FILE"
else
  echo "Failed to restore database $PGDATABASE from $BACKUP_FILE"
  exit 1
fi
