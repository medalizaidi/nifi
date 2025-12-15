#!/bin/bash

NIFI_URL=$1
FLOW_XML=$2

curl -X POST \
  "$NIFI_URL/nifi-api/process-groups/root/process-groups/import" \
  -F "file=@$FLOW_XML"

echo "Flow imported into $NIFI_URL"
