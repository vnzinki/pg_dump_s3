FROM alpine:latest

ARG PG_VERSION=latest
ARG AWSCLI_VERSION=latest

RUN apk add postgresql-client=${PG_VERSION} \
  && aws-cli=${AWSCLI_VERSION}
