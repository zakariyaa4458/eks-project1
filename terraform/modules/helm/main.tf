resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.21.0"
  namespace        = "cert-manager"
  create_namespace = true

  values = [

    "${file("helm-values/cert-manager.yaml")}"

  ]


}


resource "helm_release" "traefik" {

  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = "39.0.0"
  namespace        = "traefik"
  create_namespace = true
  depends_on = [ var.module_aws_load_balancer_controller ]



  values = [
    <<-EOT
      installCRDs: true
    EOT
    ,
    "${file("helm-values/traefik.yaml")}"
  ]

}






resource "helm_release" "external_dns" {

  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = "1.21.1"
  namespace        = "external-dns"
  create_namespace = true





  values = [
    <<-EOT
      installCRDs: true
    EOT
    ,

    "${file("helm-values/external-dns.yaml")}"
  ]

  depends_on = [
    var.module_external_dns
  ]

}


resource "helm_release" "argocd_deploy" {

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.19.15"
  timeout    = "600"

  namespace        = "argo-cd"
  create_namespace = true

  values = [
    "${file("helm-values/argo-cd.yaml")}"
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










#resource "helm_release" "aws_load_balancer_controller" {
# name       = "aws-load-balancer-controller"
#repository = "https://aws.github.io/eks-charts"
#chart      = "aws-load-balancer-controller"
#version    = "3.4.3"

# namespace        = "kube-system"
#create_namespace = false

#values = [
# file("helm-values/aws-load-balancer-controller.yaml")

#]

#set = [
# {
#   name  = "vpcId"
#  value = aws_vpc.main.id
#}
#]
#}