#!/bin/bash

# Load environment variables from a .env file (if using one)
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Ensure all required environment variables are set
REQUIRED_VARS="PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION S3_BUCKET S3_PATH"

# Check if each required variable is set
for var in $REQUIRED_VARS; do
  if [ -z "$(eval echo \$$var)" ]; then
    echo "Error: Environment variable $var is not set."
    exit 1
  fi
done

# Get current date and time (format: YYYY-MM-DD_HH-MM-SS)
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Define output file with timestamp
OUTPUT_FILE=${OUTPUT_FILE:-"${PGDATABASE}_dump_${TIMESTAMP}.sql"}

# Export PGPASSWORD to avoid password prompt
export PGPASSWORD=$PGPASSWORD

# Run pg_dump
pg_dump -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -Fc -bvOx -f  $OUTPUT_FILE

if [ $? -eq 0 ]; then
  echo "Database dump completed: $OUTPUT_FILE"

  # Upload to S3
  aws s3 cp $OUTPUT_FILE s3://$S3_BUCKET/$S3_PATH/$OUTPUT_FILE

  if [ $? -eq 0 ]; then
    echo "Successfully uploaded $OUTPUT_FILE to s3://$S3_BUCKET/$S3_PATH/$OUTPUT_FILE"
  else
    echo "Failed to upload $OUTPUT_FILE to S3"
    exit 1
  fi

  # Optionally, delete the local file after upload
  # rm -f $OUTPUT_FILE
else
  echo "Database dump failed!"
  exit 1
fi
