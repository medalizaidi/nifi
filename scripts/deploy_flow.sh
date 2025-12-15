#!/bin/bash

FLOW_FILE=$1

echo "Deploying NiFi flow..."

curl -X POST \
  http://localhost:8080/nifi-api/process-groups/root/process-groups \
  -H "Content-Type: application/json" \
  -d @"$FLOW_FILE"

echo "Flow deployed."
