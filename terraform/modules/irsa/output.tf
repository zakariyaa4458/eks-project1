output "karpeneter_module" {
    value = module.karpenter
  
}

output "module_karpenter_queue_name" {
    value = module.karpenter.queue_name
  
}

output "module_external_dns" {
    value = module.external-dns
  
}

output "module_aws_load_balancer_controller" {
    value = module.aws-load-balancer-controller
  
}