import nipyapi
import requests
import json
import os
import time
import logging
from datetime import datetime
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration
REGISTRY_URL = os.environ.get('NIFI_REGISTRY_URL', 'http://localhost:18080/nifi-registry-api')
GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN')
GITHUB_REPO = os.environ.get('GITHUB_REPO')  # format: owner/repo
GITHUB_BRANCH = os.environ.get('GITHUB_BRANCH', 'main')
POLL_INTERVAL = int(os.environ.get('POLL_INTERVAL', '60'))  # seconds
STATE_FILE = os.environ.get('STATE_FILE', '/app/data/sync_state.json')

class NiFiRegistryGitSync:
    def __init__(self):
        self.registry_url = REGISTRY_URL
        self.github_token = GITHUB_TOKEN
        self.github_repo = GITHUB_REPO
        self.github_branch = GITHUB_BRANCH
        self.state_file = STATE_FILE
        self.state = self.load_state()
        
        # Configure nipyapi
        nipyapi.config.registry_config.host = self.registry_url
        
        # GitHub API setup
        self.github_api_url = f"https://api.github.com/repos/{self.github_repo}"
        self.github_headers = {
            'Authorization': f'token {self.github_token}',
            'Accept': 'application/vnd.github.v3+json'
        }
    
    def load_state(self):
        """Load the last known state from file"""
        try:
            if os.path.exists(self.state_file):
                with open(self.state_file, 'r') as f:
                    return json.load(f)
        except Exception as e:
            logger.warning(f"Could not load state file: {e}")
        return {}
    
    def save_state(self):
        """Save the current state to file"""
        try:
            os.makedirs(os.path.dirname(self.state_file), exist_ok=True)
            with open(self.state_file, 'w') as f:
                json.dump(self.state, f, indent=2)
        except Exception as e:
            logger.error(f"Could not save state file: {e}")
    
    def get_buckets(self):
        """Get all buckets from NiFi Registry"""
        try:
            buckets = nipyapi.versioning.list_registry_buckets()
            return buckets
        except Exception as e:
            logger.error(f"Error fetching buckets: {e}")
            return []
    
    def get_flows_in_bucket(self, bucket_id):
        """Get all flows in a bucket"""
        try:
            flows = nipyapi.versioning.list_flows_in_bucket(bucket_id)
            return flows
        except Exception as e:
            logger.error(f"Error fetching flows for bucket {bucket_id}: {e}")
            return []
    
    def get_flow_versions(self, bucket_id, flow_id):
        """Get all versions of a flow"""
        try:
            versions = nipyapi.versioning.list_flow_versions(bucket_id, flow_id)
            return versions
        except Exception as e:
            logger.error(f"Error fetching versions for flow {flow_id}: {e}")
            return []
    
    def get_flow_version_content(self, bucket_id, flow_id, version):
        """Get the content of a specific flow version"""
        try:
            # Use the NiFi Registry API directly
            url = f"{self.registry_url}/buckets/{bucket_id}/flows/{flow_id}/versions/{version}"
            response = requests.get(url)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Error fetching flow version content: {e}")
            return None
    
    def commit_to_github(self, file_path, content, commit_message):
        """Commit a file to GitHub"""
        try:
            # Get current file SHA if it exists
            get_url = f"{self.github_api_url}/contents/{file_path}?ref={self.github_branch}"
            response = requests.get(get_url, headers=self.github_headers)
            
            sha = None
            if response.status_code == 200:
                sha = response.json()['sha']
            
            # Prepare commit data
            import base64
            content_encoded = base64.b64encode(json.dumps(content, indent=2).encode()).decode()
            
            data = {
                'message': commit_message,
                'content': content_encoded,
                'branch': self.github_branch
            }
            
            if sha:
                data['sha'] = sha
            
            # Create/update file
            put_url = f"{self.github_api_url}/contents/{file_path}"
            response = requests.put(put_url, headers=self.github_headers, json=data)
            response.raise_for_status()
            
            logger.info(f"✓ Committed to GitHub: {file_path}")
            return True
            
        except Exception as e:
            logger.error(f"Error committing to GitHub: {e}")
            return False
    
    def sync_flow_version(self, bucket, flow, version_num):
        """Sync a specific flow version to GitHub"""
        try:
            # Get flow content
            content = self.get_flow_version_content(
                bucket.identifier,
                flow.identifier,
                version_num
            )
            
            if not content:
                return False
            
            # Create file path
            file_path = f"flows/{bucket.name}/{flow.name}/v{version_num}.json"
            
            # Create commit message
            commit_message = f"Update {flow.name} to version {version_num}\n\nBucket: {bucket.name}\nFlow: {flow.name}\nVersion: {version_num}"
            
            # Commit to GitHub
            return self.commit_to_github(file_path, content, commit_message)
            
        except Exception as e:
            logger.error(f"Error syncing flow version: {e}")
            return False
    
    def check_for_updates(self):
        """Check for new versions and sync to GitHub"""
        logger.info("Checking for updates...")
        
        buckets = self.get_buckets()
        changes_detected = False
        
        for bucket in buckets:
            bucket_key = bucket.identifier
            
            # Initialize bucket in state if not exists
            if bucket_key not in self.state:
                self.state[bucket_key] = {}
            
            flows = self.get_flows_in_bucket(bucket.identifier)
            
            for flow in flows:
                flow_key = flow.identifier
                
                # Get latest version
                versions = self.get_flow_versions(bucket.identifier, flow.identifier)
                
                if not versions:
                    continue
                
                latest_version = versions[0].version
                
                # Check if this is a new version
                if flow_key not in self.state[bucket_key]:
                    # First time seeing this flow
                    logger.info(f"New flow detected: {bucket.name}/{flow.name} v{latest_version}")
                    self.state[bucket_key][flow_key] = latest_version
                    
                    # Sync this version
                    if self.sync_flow_version(bucket, flow, latest_version):
                        changes_detected = True
                    
                elif latest_version > self.state[bucket_key][flow_key]:
                    # New version detected
                    old_version = self.state[bucket_key][flow_key]
                    logger.info(f"New version detected: {bucket.name}/{flow.name} v{old_version} -> v{latest_version}")
                    
                    # Sync all versions between old and new
                    for v in range(old_version + 1, latest_version + 1):
                        if self.sync_flow_version(bucket, flow, v):
                            changes_detected = True
                    
                    # Update state
                    self.state[bucket_key][flow_key] = latest_version
        
        if changes_detected:
            self.save_state()
            logger.info("✓ Changes synced to GitHub")
        else:
            logger.info("No changes detected")
        
        return changes_detected
    
    def run(self):
        """Main run loop"""
        logger.info("Starting NiFi Registry to GitHub Sync Service")
        logger.info(f"Registry: {self.registry_url}")
        logger.info(f"GitHub Repo: {self.github_repo}")
        logger.info(f"Branch: {self.github_branch}")
        logger.info(f"Poll Interval: {POLL_INTERVAL}s")
        logger.info("-" * 60)
        
        while True:
            try:
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                logger.info(f"[{timestamp}] Polling NiFi Registry...")
                
                self.check_for_updates()
                
            except KeyboardInterrupt:
                logger.info("Shutting down...")
                break
            except Exception as e:
                logger.error(f"Error in main loop: {e}", exc_info=True)
            
            time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    sync = NiFiRegistryGitSync()
    sync.run()