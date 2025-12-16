#!/bin/bash

echo "============================================"
echo "Fixing Git Repository Uncommitted Changes"
echo "============================================"
echo ""

echo "1. Stopping registry container..."
docker-compose stop registry
echo ""

echo "2. Checking Git status in flow_storage..."
cd registry/flow_storage

echo "Current Git status:"
git status
echo ""

echo "3. Committing any uncommitted changes..."
if ! git diff-index --quiet HEAD --; then
    echo "Found uncommitted changes, committing them..."
    git add -A
    git commit -m "Cleanup: Commit pending changes before flow versioning"
    echo "✅ Changes committed"
else
    echo "✅ No uncommitted changes found"
fi
echo ""

echo "4. Checking for untracked files..."
if [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo "Found untracked files, adding them..."
    git add -A
    git commit -m "Add untracked files"
    echo "✅ Untracked files committed"
else
    echo "✅ No untracked files"
fi
echo ""

echo "5. Verifying Git status is clean..."
if git diff-index --quiet HEAD --; then
    echo "✅ Git repository is clean"
else
    echo "⚠️  Still have uncommitted changes, trying to reset..."
    git reset --hard HEAD
    echo "✅ Repository reset to clean state"
fi

cd ../..
echo ""

echo "6. Starting registry container..."
docker-compose up -d registry
echo ""

echo "============================================"
echo "Git Repository Cleaned!"
echo "============================================"
echo ""
echo "Wait a few seconds for the registry to start, then try:"
echo "1. Version control your process group in NiFi"
echo "2. The flow should now save successfully"
echo ""
echo "Monitor logs: docker-compose logs -f registry"
