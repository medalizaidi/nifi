#!/bin/bash

echo "============================================"
echo "Fix Automatic Push to GitHub"
echo "============================================"
echo ""

echo "The issue: Local branch is 'master' but GitHub has 'main'"
echo "This causes automatic pushes to fail silently."
echo ""
echo "Fix: Rename local branch to 'main' and configure tracking"
echo ""

cd registry/flow_storage

echo "1. Current branch status..."
echo "Local branch:"
git branch --show-current
echo ""
echo "Remote branches:"
git branch -r
echo ""

echo "2. Renaming master to main..."
git branch -m master main
echo "✅ Branch renamed to 'main'"
echo ""

echo "3. Setting up tracking with remote main..."
git push -u origin main
PUSH_RESULT=$?

if [ $PUSH_RESULT -eq 0 ]; then
    echo "✅ Successfully pushed and set up tracking!"
else
    echo "❌ Push failed. Check your GitHub token."
    cd ../..
    exit 1
fi
echo ""

echo "4. Verifying configuration..."
echo "Current branch:"
git branch --show-current
echo ""
echo "Tracking branch:"
git status -sb
echo ""

cd ../..

echo "5. Restarting registry to pick up new branch configuration..."
docker-compose restart registry
echo ""

echo "6. Waiting for registry to start (15 seconds)..."
sleep 15
echo ""

echo "============================================"
echo "Fix Complete!"
echo "============================================"
echo ""
echo "✅ Local branch renamed to 'main'"
echo "✅ Tracking configured with origin/main"
echo "✅ Registry restarted"
echo ""
echo "Now when you commit flows in NiFi:"
echo "1. NiFi Registry will commit to local 'main' branch"
echo "2. Git will automatically push to GitHub 'main' branch"
echo ""
echo "Test it:"
echo "1. Make a change to a versioned flow in NiFi"
echo "2. Commit the change"
echo "3. Wait 60 seconds"
echo "4. Check: docker-compose logs registry | grep -i push"
echo "5. Check GitHub: https://github.com/medalizaidi/nifi"
echo ""
