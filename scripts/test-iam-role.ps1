param([string]$ExpectedAccount = '241533156847')
$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw 'AWS CLI is not installed or is not on PATH. Install AWS CLI v2, then reopen PowerShell.'
}

$identityJson = aws sts get-caller-identity --output json
if ($LASTEXITCODE -ne 0) { throw 'No valid AWS session. Load the current Learner Lab credentials into this PowerShell window first.' }
$identity = ($identityJson -join "`n") | ConvertFrom-Json
if ($identity.Account -ne $ExpectedAccount) {
    throw "Account mismatch: current=$($identity.Account), expected=$ExpectedAccount. No role was created."
}
Write-Host "Testing IAM in account $($identity.Account), caller $($identity.Arn)"

$roleName = 'codex-iam-probe-' + [Guid]::NewGuid().ToString('N')
$policyFile = Join-Path ([IO.Path]::GetTempPath()) ($roleName + '.json')
$created = $false
try {
    $policy = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
    [IO.File]::WriteAllText($policyFile, $policy, [Text.UTF8Encoding]::new($false))
    $policyUri = 'file://' + ($policyFile -replace '\\', '/')
    $roleArn = aws iam create-role --role-name $roleName --assume-role-policy-document $policyUri --description 'Temporary Learner Lab IAM CreateRole permission probe; no permission policies attached' --query Role.Arn --output text
    if ($LASTEXITCODE -ne 0) { throw 'IAM CreateRole failed. Read the AWS error above; no policy was attached.' }
    $created = $true
    Write-Host "PASS: iam:CreateRole succeeded. Temporary role: $roleArn"
    Write-Host 'No permission policy, instance profile, or workload was attached to this role.'
} finally {
    if ($created) {
        aws iam delete-role --role-name $roleName
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Cleanup failed. Delete the temporary role with: aws iam delete-role --role-name $roleName"
        } else {
            Write-Host 'PASS: iam:DeleteRole succeeded; temporary role removed.'
        }
    }
    if (Test-Path -LiteralPath $policyFile) { Remove-Item -LiteralPath $policyFile }
}
Write-Host 'This probe does not test CreatePolicy, AttachRolePolicy, PassRole, OIDC provider creation, or the permissions needed by EKS/IRSA.'
