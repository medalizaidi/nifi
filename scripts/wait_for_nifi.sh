#!/bin/bash

echo "Waiting for NiFi to be ready..."

until curl -s http://localhost:8080/nifi-api/system-diagnostics > /dev/null; do
  sleep 5
done

echo "NiFi is ready!"