#!/usr/bin/env bash
# Read-only prerequisites for the GitHub runner. Never prints credential values.
set -euo pipefail
for task_key in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN; do
  if [[ -z "${!task_key:-}" ]]; then
    echo "::error::Missing $task_key. Update the three repository secrets from your active AWS access portal session."
    exit 1
  fi
done

TASK_IDENTITY="$(aws sts get-caller-identity --output json --no-cli-pager)"
python3 - "$TASK_IDENTITY" <<'PY'
import json
import sys

identity = json.loads(sys.argv[1])
if identity.get("Account") != "241533156847":
    sys.exit("::error::Wrong AWS account; use temporary credentials for account 241533156847.")
if not identity.get("Arn", "").startswith("arn:aws:sts::241533156847:assumed-role/"):
    sys.exit("::error::Expected an assumed role session from AWS IAM Identity Center.")
print("Active AWS session: account 241533156847.")
PY

command -v terraform >/dev/null
command -v kubectl >/dev/null
command -v python3 >/dev/null
