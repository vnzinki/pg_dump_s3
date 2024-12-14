FROM alpine

ARG PG_VERSION

RUN apk add --no-cache \
  "postgresql${PG_VERSION}-client" \
  aws-cli

COPY backup.sh restore.sh ./
RUN chmod +x ./backup.sh ./restore.sh
