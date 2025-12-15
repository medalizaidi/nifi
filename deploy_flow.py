import nipyapi
import sys

# Environment: staging or prod
ENV = sys.argv[1]  # pass 'staging' or 'prod'

# Map environment to NiFi API URLs
nifi_hosts = {
    "staging": "http://nifi-stg:8080/nifi-api",
    "prod": "http://nifi-prod:8080/nifi-api"
}

# NiFi Registry
registry_client_name = "default-registry-client"
bucket_name = "my-project"
flow_name = "my-flow"

# Connect to NiFi
nipyapi.config.nifi_config.host = nifi_hosts[ENV]

# Connect to Registry (HTTP)
registry_client = nipyapi.registry.get_registry_client(registry_client_name, service_endpoint='http://registry:18080')

# Get bucket
bucket = nipyapi.registry.get_bucket(bucket_name=bucket_name, client=registry_client)

# Get latest version of the flow
versioned_flow = nipyapi.registry.get_flow(bucket.id, flow_name, version='latest')

# Get root process group
root_pg_id = nipyapi.canvas.get_root_pg_id()

# Create or update versioned group
existing_pg = nipyapi.canvas.get_process_group(flow_name, root_pg=root_pg_id)
if existing_pg:
    nipyapi.canvas.update_process_group_version(existing_pg, versioned_flow.version)
else:
    nipyapi.canvas.create_versioned_group(root_pg_id, versioned_flow, location=(0,0))

print(f"Flow deployed to {ENV} successfully!")
