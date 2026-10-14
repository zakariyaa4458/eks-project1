"""Run in CloudShell. AWS JSON uses private temporary files; kubectl uses stdin."""
import base64
import json
import os
import secrets
import subprocess
import sys
import tempfile
from urllib.parse import quote

REGION = "us-east-1"
ACCOUNT = "241533156847"


def run(args, payload=None):
    result = subprocess.run(args, input=payload, text=True, capture_output=True)
    if result.returncode:
        # AWS errors identify the operation; never print input/secret payloads.
        raise RuntimeError(result.stderr.strip())
    return result.stdout


def aws(*args, payload=None):
    command = ["aws", *args, "--region", REGION, "--output", "json", "--no-cli-pager"]
    if payload is None:
        return json.loads(run(command))
    # AWS CLI may read a parameter file more than once; stdin cannot be reread.
    json.loads(payload)
    fd, path = tempfile.mkstemp(prefix="eks-lab-secret-", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(payload)
        index = command.index("--cli-input-json") + 1
        command[index] = "file://" + path.replace("\\", "/")
        return json.loads(run(command))
    finally:
        os.unlink(path)


def apply(document):
    run(["kubectl", "apply", "--server-side", "--field-manager=learner-lab-secrets", "-f", "-"], json.dumps(document))


def secret(namespace, name, values):
    apply({"apiVersion": "v1", "kind": "Secret", "metadata": {"name": name, "namespace": namespace},
           "type": "Opaque", "data": {k: base64.b64encode(v.encode()).decode() for k, v in values.items()}})
    print(f"Ready: {namespace}/{name} (values hidden)")


def main():
    identity = aws("sts", "get-caller-identity")
    if identity["Account"] != ACCOUNT:
        raise RuntimeError("Wrong AWS account. Nothing was changed.")
    context = run(["kubectl", "config", "current-context"]).strip()
    if context != f"arn:aws:eks:{REGION}:{ACCOUNT}:cluster/eks-cluster":
        raise RuntimeError("Wrong Kubernetes context. Run aws eks update-kubeconfig for eks-cluster first.")
    # Validate the AWS session and SQS queue before creating any secret.
    credentials = aws("configure", "export-credentials", "--format", "process")
    if not credentials.get("SessionToken"):
        raise RuntimeError("Expected temporary Learner Lab credentials with a session token.")
    queue = aws("sqs", "get-queue-url", "--queue-name", "eks_sqs")["QueueUrl"]
    aws("sqs", "get-queue-attributes", "--queue-url", queue, "--attribute-names", "QueueArn")
    try:
        stored = aws("secretsmanager", "get-secret-value", "--secret-id", "eks/postgres")
        password = json.loads(stored["SecretString"])["POSTGRES_PASSWORD"]
    except RuntimeError as error:
        if "ResourceNotFoundException" not in str(error):
            raise
        pvcs = json.loads(run(["kubectl", "get", "pvc", "-A", "-o", "json"]))
        if any("postgres-data" in item["metadata"]["name"] for item in pvcs["items"]):
            raise RuntimeError("Postgres PVC exists but eks/postgres is missing. Restore the original password; do not generate a new one.")
        password = secrets.token_urlsafe(32)
        aws("secretsmanager", "create-secret", "--cli-input-json", "file:///dev/stdin",
            payload=json.dumps({"Name": "eks/postgres", "SecretString": json.dumps({"POSTGRES_PASSWORD": password})}))
        print("Created eks/postgres in Secrets Manager (password hidden).")
    if not isinstance(password, str) or not password:
        raise RuntimeError("eks/postgres must contain a nonempty POSTGRES_PASSWORD string.")
    url = "postgres://app:" + quote(password, safe="") + "@postgres-service.database-ns.svc.cluster.local:5432/orders?sslmode=disable"
    aws("secretsmanager", "put-secret-value", "--cli-input-json", "file:///dev/stdin",
        payload=json.dumps({"SecretId": "database_url", "SecretString": url}))
    for namespace in ["database-ns", "application-namespace"]:
        apply({"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": namespace}})
    secret("database-ns", "postgres-secret", {"POSTGRES_PASSWORD": password})
    secret("application-namespace", "application-secret", {"DATABASE_URL": url})
    secret("application-namespace", "application-secret-sqs", {
        "SQS_QUEUE_URL": queue, "AWS_REGION": REGION, "AWS_DEFAULT_REGION": REGION,
        "AWS_ACCESS_KEY_ID": credentials["AccessKeyId"], "AWS_SECRET_ACCESS_KEY": credentials["SecretAccessKey"],
        "AWS_SESSION_TOKEN": credentials["SessionToken"]})
    print("Secrets loaded. Session expiry:", credentials.get("Expiration", "see Learner Lab session"))
    print("After renewing the Lab session, rerun this script and restart the SQS deployments.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, KeyError, ValueError) as error:
        print("STOP:", error, file=sys.stderr)
        sys.exit(1)
