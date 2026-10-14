$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw 'Install AWS CLI v2, then reopen PowerShell.'
}
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw 'kubectl must be installed on this computer.'
}
Write-Host 'Enter the three values from AWS Details > AWS CLI of the running Lab. Values are hidden.'
$env:AWS_ACCESS_KEY_ID = [System.Net.NetworkCredential]::new('', (Read-Host 'Access key' -AsSecureString)).Password
$env:AWS_SECRET_ACCESS_KEY = [System.Net.NetworkCredential]::new('', (Read-Host 'Secret key' -AsSecureString)).Password
$env:AWS_SESSION_TOKEN = [System.Net.NetworkCredential]::new('', (Read-Host 'Session token' -AsSecureString)).Password
$env:AWS_DEFAULT_REGION = 'us-east-1'
$env:AWS_PAGER = ''
$taskIdentity = aws sts get-caller-identity --output json
if ($LASTEXITCODE -ne 0) { throw 'AWS session is invalid.' }
if ((($taskIdentity -join "`n") | ConvertFrom-Json).Account -ne '241533156847') {
    throw 'Wrong AWS account.'
}
aws eks update-kubeconfig --name eks-cluster --region us-east-1
if ($LASTEXITCODE -ne 0) { throw 'Cannot connect to eks-cluster.' }
Write-Host 'Open http://localhost:8086 after Forwarding appears. Keep this terminal running; Ctrl+C stops it.'
kubectl port-forward -n application-namespace service/dashboard-api-service 8086:80
