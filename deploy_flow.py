import nipyapi
import sys
import time
import os

# --- CONFIG ---
ENV = sys.argv[1] if len(sys.argv) > 1 else "staging"  # 'staging' or 'prod'

nifi_hosts = {
    "staging": os.getenv("NIFI_API"),
    "prod": os.getenv("NIFI_API")
}

registry_url = os.getenv("REGISTRY_API")
bucket_name = os.getenv("BUCKET_NAME", "test")
flow_name = os.getenv("FLOW_NAME", "test")

# Authentication (if needed)
nifi_username = os.getenv("NIFI_USERNAME")
nifi_password = os.getenv("NIFI_PASSWORD")

# --- VALIDATION ---
if not nifi_hosts[ENV]:
    print(f"❌ ERROR: NIFI_API environment variable is not set")
    print(f"Expected format: http://your-nifi-host:8082/nifi-api")
    sys.exit(1)

if not registry_url:
    print(f"❌ ERROR: REGISTRY_API environment variable is not set")
    print(f"Expected format: http://your-registry-host:18080")
    sys.exit(1)

# --- CONNECT ---
print(f"🔌 Connecting to NiFi at {nifi_hosts[ENV]}")
nipyapi.config.nifi_config.host = nifi_hosts[ENV]

print(f"🔌 Connecting to Registry at {registry_url}")
nipyapi.config.registry_config.host = registry_url

# Set authentication if provided
if nifi_username and nifi_password:
    print(f"🔐 Using authentication for user: {nifi_username}")
    nipyapi.config.nifi_config.username = nifi_username
    nipyapi.config.nifi_config.password = nifi_password

time.sleep(2)

try:
    # --- LIST BUCKETS ---
    print(f"📦 Fetching buckets from registry...")
    buckets = nipyapi.versioning.list_registry_buckets()
    
    if not buckets:
        print(f"❌ No buckets found in registry")
        sys.exit(1)
    
    print(f"✅ Found {len(buckets)} bucket(s)")
    for b in buckets:
        print(f"  - {b.name}")
    
    bucket = next((b for b in buckets if b.name == bucket_name), None)
    if not bucket:
        print(f"❌ Bucket '{bucket_name}' not found in registry")
        print(f"Available buckets: {[b.name for b in buckets]}")
        sys.exit(1)
    
    print(f"✅ Using bucket: {bucket.name}")

    # --- LIST FLOWS ---
    print(f"🔍 Fetching flows from bucket '{bucket_name}'...")
    flows = nipyapi.versioning.list_flows_in_bucket(bucket.identifier)
    
    if not flows:
        print(f"❌ No flows found in bucket '{bucket_name}'")
        sys.exit(1)
    
    print(f"✅ Found {len(flows)} flow(s)")
    for f in flows:
        print(f"  - {f.name}")
    
    flow = next((f for f in flows if f.name == flow_name), None)
    if not flow:
        print(f"❌ Flow '{flow_name}' not found in bucket '{bucket_name}'")
        print(f"Available flows: {[f.name for f in flows]}")
        sys.exit(1)
    
    print(f"✅ Using flow: {flow.name}")

    # --- GET LATEST VERSION ---
    print(f"📋 Fetching versions...")
    versions = nipyapi.versioning.list_flow_versions(bucket.identifier, flow.identifier)
    
    if not versions:
        print(f"❌ No versions found for flow '{flow_name}'")
        sys.exit(1)
    
    latest_ver = versions[0].version
    print(f"✅ Latest version: {latest_ver}")

    # --- GET REGISTRY CLIENT ---
    print(f"🔗 Fetching registry clients...")
    registry_clients = nipyapi.versioning.list_registry_clients()
    
    if not registry_clients or not registry_clients.registries:
        print(f"❌ No registry clients configured in NiFi")
        print(f"Please add a registry client in NiFi UI:")
        print(f"  1. Go to NiFi UI → Controller Settings")
        print(f"  2. Registry Clients tab → + button")
        print(f"  3. Name: NiFi Registry")
        print(f"  4. URL: {registry_url}")
        sys.exit(1)
    
    reg_client_id = registry_clients.registries[0].id
    print(f"✅ Using registry client ID: {reg_client_id}")

    # --- DEPLOY / UPDATE ---
    print(f"🚀 Deploying flow to {ENV}...")
    root_pg_id = nipyapi.canvas.get_root_pg_id()
    
    # Search for existing process group by name in the root
    all_pgs = nipyapi.canvas.list_all_process_groups()
    existing = next((pg for pg in all_pgs if pg.status.name == flow_name and pg.status.parent_group_id == root_pg_id), None)
    
    if existing:
        print(f"♻️  Updating existing flow '{flow_name}' to version {latest_ver}")
        nipyapi.versioning.update_flow_ver(existing, latest_ver)
    else:
        print(f"🆕 Deploying new flow '{flow_name}' version {latest_ver}")
        nipyapi.versioning.deploy_flow_version(
            parent_id=root_pg_id,
            location=(0, 0),
            bucket_id=bucket.identifier,
            flow_id=flow.identifier,
            reg_client_id=reg_client_id,
            version=latest_ver
        )
    
    print(f"✅ Flow '{flow_name}' deployed to {ENV} successfully!")
    print(f"🎉 Deployment complete!")

except Exception as e:
    print(f"❌ ERROR: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
