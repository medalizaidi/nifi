#!/bin/bash

echo "Starting all processors..."

PG_ID=$(curl -s http://localhost:8080/nifi-api/process-groups/root | jq -r '.component.id')

curl -X PUT \
  http://localhost:8080/nifi-api/flow/process-groups/$PG_ID \
  -H "Content-Type: application/json" \
  -d '{
    "id": "'$PG_ID'",
    "state": "RUNNING"
  }'

echo "Flow started."
