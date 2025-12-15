#!/bin/bash

FLOW_ID=$1
VERSION=$2

REGISTRY_URL=http://registry:18080

curl -s \
  "$REGISTRY_URL/nifi-registry-api/flows/$FLOW_ID/versions/$VERSION/export" \
  -o flow.xml

echo "Flow exported from registry"
