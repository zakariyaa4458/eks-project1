#!/usr/bin/env bash
# CloudShell/GitHub Actions entry point. No plaintext credential files or set -x.
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1 AWS_PAGER=""
ACTION="${1:-all}"
case "$ACTION" in all|infra|platform|refresh|destroy) ;; *) echo 'Use: all | infra | platform | refresh | destroy'; exit 1 ;; esac

TASK_ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
if [[ "$TASK_ACCOUNT" != 241533156847 ]]; then
  echo 'STOP: wrong AWS account.' >&2; exit 1
fi

# Reuse the existing backend bucket, including the previous CloudShell setup.
if [[ -z "${STATE_BUCKET:-}" && -f "$TASK_ROOT/.lab-state-bucket" ]]; then
  STATE_BUCKET="$(cat "$TASK_ROOT/.lab-state-bucket")"
fi
if [[ -z "${STATE_BUCKET:-}" ]]; then
  STATE_BUCKET="$(python3 - "$TASK_ROOT" <<'PY'
import json, os, pathlib, sys
root = pathlib.Path(sys.argv[1])
paths = [root / 'terraform/.terraform/terraform.tfstate']
if os.environ.get('TF_DATA_DIR'):
    paths.insert(0, pathlib.Path(os.environ['TF_DATA_DIR']) / 'terraform.tfstate')
paths += [pathlib.Path('/tmp/eks-terraform-data/terraform.tfstate'), pathlib.Path('/tmp/eks-tf-infra/terraform.tfstate')]
for path in paths:
    if path.exists():
        backend = json.loads(path.read_text()).get('backend', {})
        bucket = backend.get('config', {}).get('bucket')
        if backend.get('type') == 's3' and bucket and not bucket.startswith('REPLACE_'):
            print(bucket); break
PY
)"
fi
STATE_BUCKET="${STATE_BUCKET:-eks-project1-tfstate-241533156847-us-east-1}"
export STATE_BUCKET
if [[ "$ACTION" == destroy ]]; then
  aws s3api head-bucket --bucket "$STATE_BUCKET"
elif ! aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
  aws s3api create-bucket --bucket "$STATE_BUCKET" --region us-east-1 >/dev/null
fi
if [[ "$ACTION" != destroy ]]; then
  aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled
  aws s3api put-public-access-block --bucket "$STATE_BUCKET" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  aws s3api put-bucket-encryption --bucket "$STATE_BUCKET" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
  aws s3api put-bucket-tagging --bucket "$STATE_BUCKET" --tagging 'TagSet=[{Key=Project,Value=eks-project1},{Key=Owner,Value=anhhao1712},{Key=Environment,Value=learning},{Key=ManagedBy,Value=GitHubActions}]'
fi
printf '%s\n' "$STATE_BUCKET" > "$TASK_ROOT/.lab-state-bucket"
export TF_IN_AUTOMATION=1

infra_init() {
  export TF_DATA_DIR=/tmp/eks-tf-infra
  mkdir -p "$TF_DATA_DIR"
  terraform -chdir="$TASK_ROOT/terraform" init -input=false -reconfigure -backend-config="bucket=$STATE_BUCKET"
}

platform_init() {
  export TF_VAR_platform_config
  TF_VAR_platform_config="$(TF_DATA_DIR=/tmp/eks-tf-infra terraform -chdir="$TASK_ROOT/terraform" output -json platform_config)"
  export TF_VAR_sqs_credentials
  TF_VAR_sqs_credentials="$(aws configure export-credentials --format process)"
  export TF_DATA_DIR=/tmp/eks-tf-platform
  mkdir -p "$TF_DATA_DIR"
  terraform -chdir="$TASK_ROOT/terraform/platform" init -input=false -reconfigure -backend-config="bucket=$STATE_BUCKET"
  aws eks update-kubeconfig --name eks-cluster --region us-east-1 >/dev/null
  # Use the active AWS IAM Identity Center role for Kubernetes access.
  if [[ "$(kubectl auth can-i create clusterroles 2>/dev/null)" != yes ]]; then
    echo 'STOP: current AWS identity cannot administer this EKS cluster. Use the IAM Identity Center role that created the cluster; do not create another cluster/state.' >&2
    exit 1
  fi
}

apply_infra() {
  # A previous destroy may have scheduled this project secret for deletion.
  local task_deleted
  task_deleted="$(aws secretsmanager describe-secret --secret-id database_url --query DeletedDate --output text 2>/dev/null || true)"
  if [[ -n "$task_deleted" && "$task_deleted" != None ]]; then
    aws secretsmanager restore-secret --secret-id database_url >/dev/null
    if ! terraform -chdir="$TASK_ROOT/terraform" state list | grep -Fxq 'module.security.aws_secretsmanager_secret.database_url'; then
      local task_secret_arn
      task_secret_arn="$(aws secretsmanager describe-secret --secret-id database_url --query ARN --output text)"
      terraform -chdir="$TASK_ROOT/terraform" import -var-file=learner-lab.tfvars module.security.aws_secretsmanager_secret.database_url "$task_secret_arn"
    fi
  fi
  terraform -chdir="$TASK_ROOT/terraform" apply -input=false -auto-approve -var-file=learner-lab.tfvars
}

case "$ACTION" in
  all|infra)
    infra_init
    apply_infra
    if [[ "$ACTION" == all ]]; then
      platform_init
      terraform -chdir="$TASK_ROOT/terraform/platform" apply -input=false -auto-approve
    fi
    ;;
  platform|refresh)
    infra_init
    platform_init
    terraform -chdir="$TASK_ROOT/terraform/platform" apply -input=false -auto-approve
    if [[ "$ACTION" == refresh ]]; then
      kubectl rollout restart deployment/order-service-deployment deployment/payment-service-deployment deployment/shipping-service-deployment deployment/worker-deployment -n application-namespace
    fi
    ;;
  destroy)
    infra_init
    platform_init
    # Keep EBS CSI running until Kubernetes has deleted its volumes.
    TASK_PVS="$(kubectl get pv -o json | python3 -c 'import json,sys; print(" ".join(x["metadata"]["name"] for x in json.load(sys.stdin)["items"] if x.get("spec",{}).get("claimRef",{}).get("namespace") in ["database-ns","application-namespace"]))')"
    # infra-only runs may not have installed Argo's Application CRD yet.
    if kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
      kubectl delete application root-app -n argo-cd --ignore-not-found
      kubectl delete application application database infrastructure -n argo-cd --ignore-not-found
    fi
    kubectl delete namespace application-namespace database-ns --ignore-not-found --timeout=600s
    for task_pv in $TASK_PVS; do
      kubectl wait --for=delete "pv/$task_pv" --timeout=300s
    done
    terraform -chdir="$TASK_ROOT/terraform/platform" destroy -input=false -auto-approve
    export TF_DATA_DIR=/tmp/eks-tf-infra
    terraform -chdir="$TASK_ROOT/terraform" destroy -input=false -auto-approve -var-file=learner-lab.tfvars
    echo "Destroyed project infrastructure. State bucket retained: $STATE_BUCKET"
    exit 0
    ;;
esac

if [[ "$ACTION" == all || "$ACTION" == platform ]]; then
  echo 'Run app-cd pipeline on main with the current AWS credentials. Argo will deploy the published image tags.'
fi
TF_DATA_DIR=/tmp/eks-tf-infra terraform -chdir="$TASK_ROOT/terraform" output -raw dashboard_url
printf '\n'
