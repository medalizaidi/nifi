#!/bin/bash

echo "============================================"
echo "Complete Fresh Start - NiFi Registry"
echo "============================================"
echo ""
echo "⚠️  WARNING: This will delete ALL existing flow versions!"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read
echo ""

echo "1. Stopping all containers..."
docker-compose down
echo ""

echo "2. Backing up current data..."
timestamp=$(date +%Y%m%d_%H%M%S)
if [ -d "registry" ]; then
    mv registry "registry_backup_$timestamp"
    echo "✅ Backup created: registry_backup_$timestamp"
fi
echo ""

echo "3. Creating fresh directory structure..."
mkdir -p registry/flow_storage
mkdir -p registry/extension_bundles
mkdir -p registry/database
echo "✅ Directories created"
echo ""

echo "4. Copying providers.xml..."
if [ -f "registry_backup_$timestamp/providers.xml" ]; then
    cp "registry_backup_$timestamp/providers.xml" registry/providers.xml
    echo "✅ Copied providers.xml from backup"
elif [ -f "providers.xml" ]; then
    cp providers.xml registry/providers.xml
    echo "✅ Copied providers.xml"
else
    echo "❌ No providers.xml found! Creating a template..."
    cat > registry/providers.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<providers>
    <flowPersistenceProvider>
        <class>org.apache.nifi.registry.provider.flow.git.GitFlowPersistenceProvider</class>
        <property name="Flow Storage Directory">/opt/nifi-registry/nifi-registry-current/flow_storage</property>
        <property name="Remote To Push">origin</property>
        <property name="Remote Access User">medalizaidi</property>
        <property name="Remote Access Password">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</property>
    </flowPersistenceProvider>
    <extensionBundlePersistenceProvider>
        <class>org.apache.nifi.registry.provider.extension.FileSystemBundlePersistenceProvider</class>
        <property name="Extension Bundle Storage Directory">/opt/nifi-registry/nifi-registry-current/extension_bundles</property>
    </extensionBundlePersistenceProvider>
</providers>
EOF
    echo "⚠️  You need to edit registry/providers.xml and add your GitHub token!"
fi
echo ""

echo "5. Initializing fresh Git repository..."
cd registry/flow_storage
git init -b main
git config user.name "NiFi Registry"
git config user.email "nifi-registry@apache.org"
git config core.fileMode false

# Add remote
git remote add origin https://github.com/medalizaidi/nifi.git

# Create initial commit
echo "# NiFi Flow Registry" > README.md
git add README.md
git commit -m "Initial commit"

echo "✅ Git repository initialized"
cd ../..
echo ""

echo "6. Setting permissions..."
chmod -R 777 registry/flow_storage
chmod -R 777 registry/extension_bundles
chmod -R 777 registry/database
echo "✅ Permissions set"
echo ""

echo "7. Starting containers..."
docker-compose up -d
echo ""

echo "8. Waiting for services to start (20 seconds)..."
sleep 20
echo ""

echo "============================================"
echo "Fresh Start Complete!"
echo "============================================"
echo ""
echo "✅ NiFi Registry: http://localhost:18080/nifi-registry"
echo "✅ NiFi Dev: http://localhost:8081/nifi"
echo "✅ NiFi Staging: http://localhost:8082/nifi"
echo "✅ NiFi Production: http://localhost:8083/nifi"
echo ""
echo "Next Steps:"
echo "1. Open NiFi Registry"
echo "2. Create a NEW bucket (e.g., 'dev-flows')"
echo "3. In NiFi, add Registry Client:"
echo "   - URL: http://registry:18080"
echo "4. Version control your process group"
echo ""
echo "Check logs: docker-compose logs -f registry"
echo ""
