"""Patch the pinned EBS Helm chart using only Python's standard library."""
import re
import sys

documents = re.split(r"(?m)^---[ \t]*$", sys.stdin.read())
patched = 0
for index, document in enumerate(documents):
    if not re.search(r"(?m)^kind: Deployment\s*$", document):
        continue
    if not re.search(r"(?m)^  name: [\"']?ebs-csi-controller[\"']?\s*$", document):
        continue
    document = re.sub(r"(?m)^      (hostNetwork|dnsPolicy):[^\n]*\n", "", document)
    document, count = re.subn(
        r"(?m)^    spec:\s*\n",
        "    spec:\n      hostNetwork: true\n      dnsPolicy: ClusterFirstWithHostNet\n",
        document,
        count=1,
    )
    if count != 1:
        sys.exit("EBS post-renderer: controller Pod spec not found.")
    documents[index] = document
    patched += 1

if patched != 1:
    sys.exit("EBS post-renderer: expected exactly one ebs-csi-controller Deployment.")
sys.stdout.write("---".join(documents))
