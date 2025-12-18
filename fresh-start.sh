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

echo "5. Setting up separate flows repository..."
cd registry/flow_storage

# Use a separate repository for flows only
FLOWS_REPO="https://github.com/medalizaidi/nifi-flows.git"

echo "Checking if flows repository exists..."
if git ls-remote "$FLOWS_REPO" main &>/dev/null; then
    echo "✅ Flows repository exists, cloning..."
    
    # Clone the repo
    git clone -b main "$FLOWS_REPO" temp_clone
    
    # Move .git directory
    mv temp_clone/.git .
    
    # Copy any existing files
    if [ -d "temp_clone" ]; then
        cp -r temp_clone/* . 2>/dev/null || true
        cp -r temp_clone/.[!.]* . 2>/dev/null || true
    fi
    
    # Clean up
    rm -rf temp_clone
    
    echo "✅ Synced with existing flows repository"
elif git ls-remote "$FLOWS_REPO" &>/dev/null; then
    echo "⚠️  Repository exists but no 'main' branch"
    echo "Cloning and creating main branch..."
    
    git clone "$FLOWS_REPO" temp_clone 2>/dev/null || git init temp_clone
    cd temp_clone
    git checkout -b main 2>/dev/null || git branch -M main
    cd ..
    
    mv temp_clone/.git .
    rm -rf temp_clone
    
    echo "# NiFi Flow Registry" > README.md
    echo "" >> README.md
    echo "This repository contains versioned NiFi flows managed by NiFi Registry." >> README.md
    echo "" >> README.md
    echo "## Structure" >> README.md
    echo "- Each bucket is a directory" >> README.md
    echo "- Each flow is stored as JSON snapshots" >> README.md
    echo "" >> README.md
    echo "## Managed by" >> README.md
    echo "NiFi Registry with Git-based flow persistence" >> README.md
    
    git add README.md
    git commit -m "Initial commit - NiFi Registry flow storage"
    git push -u origin main
    
    echo "✅ Created main branch and pushed"
else
    echo "⚠️  Flows repository doesn't exist!"
    echo ""
    echo "Please create a new repository on GitHub:"
    echo "  1. Go to: https://github.com/new"
    echo "  2. Repository name: nifi-flows"
    echo "  3. Description: NiFi Registry Flow Storage"
    echo "  4. Private/Public: Your choice"
    echo "  5. DON'T initialize with README (we'll do that)"
    echo "  6. Click 'Create repository'"
    echo ""
    echo "Then run this script again, or initialize manually:"
    echo ""
    
    # Initialize anyway for local use
    git init -b main
    git config user.name "NiFi Registry"
    git config user.email "nifi-registry@apache.org"
    git config core.fileMode false
    
    # Add remote (even if it doesn't exist yet)
    git remote add origin "$FLOWS_REPO" 2>/dev/null || true
    
    # Create initial commit
    echo "# NiFi Flow Registry" > README.md
    echo "" >> README.md
    echo "This repository contains versioned NiFi flows managed by NiFi Registry." >> README.md
    echo "" >> README.md
    echo "## Structure" >> README.md
    echo "- Each bucket is a directory" >> README.md
    echo "- Each flow is stored as JSON snapshots" >> README.md
    echo "" >> README.md
    echo "## Managed by" >> README.md
    echo "NiFi Registry with Git-based flow persistence" >> README.md
    
    git add README.md
    git commit -m "Initial commit - NiFi Registry flow storage"
    
    echo "✅ Local Git repository initialized"
    echo "⚠️  Create the GitHub repo, then run: cd registry/flow_storage && git push -u origin main"
fi

cd ../..
echo ""

echo "6. Creating .gitignore in main nifi directory..."
cat > .gitignore << 'EOF'
# NiFi Registry runtime directories
registry/flow_storage/
registry/database/
registry/extension_bundles/

# Backups
registry_backup_*/

# Python
__pycache__/
*.py[cod]
*$py.class
.Python
venv/
env/

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo
EOF
echo "✅ .gitignore created"
echo ""

echo "7. Setting permissions..."
chmod -R 777 registry/flow_storage
chmod -R 777 registry/extension_bundles
chmod -R 777 registry/database
echo "✅ Permissions set"
echo ""

echo "8. Starting containers..."
docker-compose up -d
echo ""

echo "9. Waiting for services to start (20 seconds)..."
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
echo "📁 Repository Structure:"
echo "   Main Repo (infrastructure): github.com/medalizaidi/nifi"
echo "   Flows Repo (flows only):    github.com/medalizaidi/nifi-flows"
echo ""
echo "✅ registry/ is now ignored in main repo"
echo "✅ Flows will push to separate nifi-flows repository"
echo ""
echo "Next Steps:"
echo "1. Open NiFi Registry: http://localhost:18080/nifi-registry"
echo "2. Create a NEW bucket (e.g., 'dev-flows')"
echo "3. In NiFi, add Registry Client (URL: http://registry:18080)"
echo "4. Version control your process group"
echo "5. Commits will automatically sync to github.com/medalizaidi/nifi-flows"
echo ""
echo "To commit infrastructure changes (docker-compose, CI/CD):"
echo "  git add docker-compose.yml deploy_flow.py .github/"
echo "  git commit -m 'Update infrastructure'"
echo "  git push"
echo ""
echo "Check logs: docker-compose logs -f registry"
echo ""
