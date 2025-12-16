#!/bin/bash

# Create directory structure
echo "Creating directory structure..."
mkdir -p registry/flow_storage
mkdir -p registry/extension_bundles
mkdir -p registry/database

# Copy providers.xml to the registry directory
echo "Copying providers.xml..."
cp providers.xml registry/providers.xml

# Initialize Git repository in flow_storage if it doesn't exist
if [ ! -d "registry/flow_storage/.git" ]; then
    echo "Initializing Git repository in flow_storage..."
    cd registry/flow_storage
    git init
    git config user.name "NiFi Registry"
    git config user.email "registry@nifi.apache.org"
    
    # Add remote
    git remote add origin https://github.com/medalizaidi/nifi.git
    
    # Try to pull existing content (if any)
    echo "Attempting to pull from remote repository..."
    git pull origin main --allow-unrelated-histories || echo "No existing content to pull or error occurred"
    
    cd ../..
else
    echo "Git repository already exists in flow_storage"
fi

echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Run: docker-compose up -d"
echo "2. Access NiFi Registry at: http://localhost:18080"
echo "3. Access NiFi instances at:"
echo "   - Dev: http://localhost:8081/nifi"
echo "   - Staging: http://localhost:8082/nifi"
echo "   - Production: http://localhost:8083/nifi"
echo ""
echo "NiFi credentials: admin / ctsBtRBKHRAx69EqUghvvgEvjnaLjFEB"
