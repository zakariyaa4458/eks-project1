# Personal account settings. GitHub Actions uses temporary credentials from your AWS access portal.
region                           = "us-east-1"
aws_account_id                   = "241533156847"
eks_role_arn                     = null
aws_iam_role_node_group_role_arn = null
create_iam_resources             = true
install_platform_helm            = true
enable_flow_logs                 = true
force_delete_ecr                 = true
# Node sizes retained from the current project configuration.
node_desired_size   = 3
node_min_size       = 2
node_max_size       = 3
node_instance_types = ["t3.medium"]
