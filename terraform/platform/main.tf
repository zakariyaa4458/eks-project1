terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    key          = "eks-project1/platform/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    helm       = { source = "hashicorp/helm", version = "~> 3.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.0" }
    random     = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

variable "platform_config" {
  type = object({
    cluster_name        = string, cluster_endpoint = string, cluster_ca = string,
    database_secret_arn = string, queue_url = string, ebs_csi_role_arn = string
  })
}

variable "sqs_credentials" {
  type      = object({ AccessKeyId = string, SecretAccessKey = string, SessionToken = string })
  sensitive = true
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["241533156847"]
}

provider "kubernetes" {
  host                   = var.platform_config.cluster_endpoint
  cluster_ca_certificate = base64decode(var.platform_config.cluster_ca)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.platform_config.cluster_name, "--region", "us-east-1"]
  }
}

provider "helm" {
  kubernetes = {
    host                   = var.platform_config.cluster_endpoint
    cluster_ca_certificate = base64decode(var.platform_config.cluster_ca)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.platform_config.cluster_name, "--region", "us-east-1"]
    }
  }
}

resource "helm_release" "ebs" {
  name       = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.65.1"
  timeout    = 600
  values = [yamlencode({
    controller = {
      region = "us-east-1"
      serviceAccount = {
        annotations = { "eks.amazonaws.com/role-arn" = var.platform_config.ebs_csi_role_arn }
      }
    }
  })]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argo-cd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.10.1"
  timeout          = 600
  values = [yamlencode({
    fullnameOverride = "argocd"
    crds             = { keep = false }
    server           = { service = { type = "ClusterIP" } }
    configs          = { params = { "server.insecure" = true } }
  })]
}

resource "kubernetes_namespace_v1" "app" {
  metadata {
    name   = "application-namespace"
    labels = { name = "application-namespace" }
  }
}

resource "kubernetes_namespace_v1" "database" {
  metadata {
    name   = "database-ns"
    labels = { name = "database-ns" }
  }
}

resource "random_password" "postgres" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "postgres" {
  name                    = "eks/postgres"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "postgres" {
  secret_id     = aws_secretsmanager_secret.postgres.id
  secret_string = jsonencode({ POSTGRES_PASSWORD = random_password.postgres.result })
}

locals {
  database_url = "postgres://app:${random_password.postgres.result}@postgres-service.database-ns.svc.cluster.local:5432/orders?sslmode=disable"
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id     = var.platform_config.database_secret_arn
  secret_string = local.database_url
}

resource "kubernetes_secret_v1" "postgres" {
  metadata {
    name      = "postgres-secret"
    namespace = kubernetes_namespace_v1.database.metadata[0].name
  }
  data = { POSTGRES_PASSWORD = jsondecode(aws_secretsmanager_secret_version.postgres.secret_string).POSTGRES_PASSWORD }
}

resource "kubernetes_secret_v1" "database" {
  metadata {
    name      = "application-secret"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
  data = { DATABASE_URL = aws_secretsmanager_secret_version.database.secret_string }
}

resource "kubernetes_secret_v1" "sqs" {
  metadata {
    name      = "application-secret-sqs"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
  data = {
    SQS_QUEUE_URL         = var.platform_config.queue_url
    AWS_REGION            = "us-east-1"
    AWS_DEFAULT_REGION    = "us-east-1"
    AWS_ACCESS_KEY_ID     = var.sqs_credentials.AccessKeyId
    AWS_SECRET_ACCESS_KEY = var.sqs_credentials.SecretAccessKey
    AWS_SESSION_TOKEN     = var.sqs_credentials.SessionToken
  }
}

resource "helm_release" "bootstrap" {
  name      = "eks-gitops-bootstrap"
  namespace = "argo-cd"
  chart     = "${path.module}/chart"
  timeout   = 600
  depends_on = [
    helm_release.argocd, helm_release.ebs,
    kubernetes_secret_v1.postgres, kubernetes_secret_v1.database, kubernetes_secret_v1.sqs
  ]
}
