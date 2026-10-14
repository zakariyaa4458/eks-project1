#!/usr/bin/env bash
# Deletes this deployment, including all versions of its Terraform state bucket.
# Run in CloudShell. Never deletes the shared account roles or unrelated resources.
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1 AWS_PAGER=""
export STATE_BUCKET="${STATE_BUCKET:-eks-project1-tfstate-241533156847-us-east-1}"
if [[ "$STATE_BUCKET" != eks-project1-tfstate-241533156847-us-east-1 ]]; then
  echo 'STOP: this full-cleanup script only deletes the dedicated current state bucket.' >&2
  exit 1
fi

echo "Deleting this project's workloads, EBS volumes, platform and AWS infrastructure."
echo "The state bucket is deleted only after both Terraform destroys succeed."
bash "$TASK_ROOT/scripts/deploy-lab.sh" destroy

# S3 rm alone cannot empty a versioned bucket. Delete versions and delete markers
# in batches; stop on any API error and leave the bucket for a retry.
python3 - "$STATE_BUCKET" <<'PY'
import json
import subprocess
import sys

bucket = sys.argv[1]

def aws(*args, payload=None):
    command = ["aws", *args, "--output", "json", "--no-cli-pager"]
    if payload is not None:
        command += ["--delete", json.dumps(payload)]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode:
        sys.exit(result.stderr.strip())
    return json.loads(result.stdout) if result.stdout.strip() else {}

while True:
    page = aws("s3api", "list-object-versions", "--bucket", bucket,
               "--max-keys", "1000", "--no-paginate")
    entries = page.get("Versions", []) + page.get("DeleteMarkers", [])
    if not entries:
        break
    for offset in range(0, len(entries), 1000):
        objects = [{"Key": item["Key"], "VersionId": item["VersionId"]}
                   for item in entries[offset:offset + 1000]]
        result = aws("s3api", "delete-objects", "--bucket", bucket,
                     payload={"Objects": objects, "Quiet": True})
        if result.get("Errors"):
            sys.exit("STOP: S3 could not delete all state versions: " + json.dumps(result["Errors"]))

aws("s3api", "delete-bucket", "--bucket", bucket)
print("Deleted state bucket: " + bucket)
PY

rm -f -- "$TASK_ROOT/.lab-state-bucket"
echo 'Done: current project deployment and its state bucket deleted.'
echo 'IAM roles, source code, GitHub secrets and unrelated/older resources are retained.'
