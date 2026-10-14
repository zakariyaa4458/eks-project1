resource "helm_release" "traefik" {

  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = "39.0.0"
  namespace        = "traefik"
  create_namespace = true
  depends_on = [ var.module_aws_load_balancer_controller ]



  values = [
   # <<-EOT
    #  installCRDs: true
    #EOT
    #,
    "${file("${path.root}/helm-values/traefik.yaml")}"
  ]

}

resource "helm_release" "karpenter" {
  namespace  = "kube-system"
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.9.0"
  wait       = false

  values = [
    <<-EOT

    dnsPolicy: Default
    settings:
      clusterName: ${var.aws_eks_cluster_eks_cluster_name}
      clusterEndpoint: ${var.aws_eks_cluster_eks_cluster_endpoint}
      interruptionQueue: ${var.module_karpenter_queue_name}
      enableZonalShift: true
    webhook:
      enabled: false
    EOT
  ]
}

resource "helm_release" "secrets-store-csi-driver" {
  name = "secrets-store-csi-driver"
  namespace = "kube-system"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart = "secrets-store-csi-driver"
  version = "1.6.0"
  create_namespace = true

  values = [

      "${file("${path.root}/helm-values/secret-store.yaml")}"
  ]

  
}

resource "helm_release" "prometheus" {
  name = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart = "prometheus"
  version = "29.30.0"
  namespace = "monitoring-ns"
  create_namespace = true

   values = [
    "${file("${path.root}/helm-values/values-prom.yaml")}"
  ]
}

resource "helm_release" "grafana" {
  name = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart = "grafana"
  version = "10.5.15"
  namespace = "monitoring-ns"
  create_namespace = true

   values = [
    "${file("${path.root}/helm-values/values-grafana.yaml")}"
  ]
}

resource "helm_release" "snapshot_storage_k8s_io" {
  name = "snapshot.storage.k8s.io"
  repository = "https://piraeus.io/helm-charts/"
  chart = "snapshot-controller"
  version = "5.2.0"
  namespace = "kube-system"
  create_namespace = true

   values = [
    "${file("${path.root}/helm-values/snapshot-controller.yaml")}"
  ]

}

resource "helm_release" "secrets_store_csi_driver_aws" {
  name = "secrets-store-csi-driver-aws"
  chart = "secrets-store-csi-driver-provider-aws"
  namespace = "kube-system"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  create_namespace = true
  
  values = [
    "${file("${path.root}/helm-values/secret-store-aws.yaml")}"
  ]
  
}

resource "helm_release"  "keda" {
  name = "keda"
  chart = "keda"
  repository = "https://kedacore.github.io/charts"
  namespace = "kube-system"
  create_namespace = true
  version = "2.20.2"

  values = [
    "${file("${path.root}/helm-values/keda.yaml")}"
  ]
  
}


#resource "helm_release" "aws_load_balancer_controller" {
# name       = "aws-load-balancer-controller"
#repository = "https://aws.github.io/eks-charts"
#chart      = "aws-load-balancer-controller"
#version    = "3.4.3"

# namespace        = "kube-system"
#create_namespace = false

#values = [
# file("${path.root}/helm-values/aws-load-balancer-controller.yaml")

#]

#set = [
# {
#   name  = "vpcId"
#  value = aws_vpc.main.id
#}
#]
#}