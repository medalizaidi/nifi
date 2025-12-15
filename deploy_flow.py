import nipyapi
import sys
import time

# --- CONFIG ---
ENV = sys.argv[1]  # 'staging' or 'prod'
nifi_hosts = {
    "staging": "http://localhost:8082/nifi-api",
    "prod": "http://localhost:8083/nifi-api"
}
registry_url = "http://localhost:18080/nifi-registry-api"
bucket_name = "test"
flow_name = "test"

# --- CONNECT ---
print(f"Connecting to NiFi at {nifi_hosts[ENV]}")
nipyapi.config.nifi_config.host = nifi_hosts[ENV]
print(f"Connecting to Registry at {registry_url}")
nipyapi.config.registry_config.host = registry_url
time.sleep(2)

# --- LIST BUCKETS ---
buckets = nipyapi.versioning.list_registry_buckets()
bucket = next((b for b in buckets if b.name == bucket_name), None)
if not bucket:
    raise ValueError(f"Bucket '{bucket_name}' not found in registry.")

# --- LIST FLOWS ---
flows = nipyapi.versioning.list_flows_in_bucket(bucket.identifier)
flow = next((f for f in flows if f.name == flow_name), None)
if not flow:
    raise ValueError(f"Flow '{flow_name}' not found in bucket '{bucket_name}'")

# --- GET LATEST VERSION ---
versions = nipyapi.versioning.list_flow_versions(bucket.identifier, flow.identifier)
latest_ver = versions[0].version

# --- GET REGISTRY CLIENT (even for anonymous) ---
registry_clients = nipyapi.versioning.list_registry_clients()
if not registry_clients or not registry_clients.registries:
    raise ValueError("No registry clients configured in NiFi. Please add a registry client first.")

# Use the first registry client (or find by name if you have multiple)
reg_client_id = registry_clients.registries[0].id
print(f"Using registry client ID: {reg_client_id}")

# --- DEPLOY / UPDATE ---
root_pg_id = nipyapi.canvas.get_root_pg_id()

# Search for existing process group by name in the root
all_pgs = nipyapi.canvas.list_all_process_groups()
existing = next((pg for pg in all_pgs if pg.status.name == flow_name and pg.status.parent_group_id == root_pg_id), None)

if existing:
    print(f"Updating existing flow '{flow_name}' to version {latest_ver}")
    nipyapi.versioning.update_flow_ver(existing, latest_ver)
else:
    print(f"Deploying new flow '{flow_name}' version {latest_ver}")
    nipyapi.versioning.deploy_flow_version(
        parent_id=root_pg_id,
        location=(0, 0),
        bucket_id=bucket.identifier,
        flow_id=flow.identifier,
        reg_client_id=reg_client_id,
        version=latest_ver
    )

print(f"Flow '{flow_name}' deployed to {ENV} successfully!")