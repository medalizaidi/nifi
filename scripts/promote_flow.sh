#!/bin/bash

FLOW_ID=$1
VERSION=$2

# Export from Registry
bash scripts/export_from_registry.sh $FLOW_ID $VERSION

# Deploy to STG
bash scripts/import_to_nifi.sh http://nifi-stg:8080 flow.xml

# Deploy to PROD
bash scripts/import_to_nifi.sh http://nifi-prod:8080 flow.xml
