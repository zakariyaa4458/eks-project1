# Ecommerce App - AWS EKS Dev-Ops Deployment

A dev-ops project that deploys 9 services as part of an ecommerce app to AWS using Terraform, Docker, Helm and GitHub Actions.

---

## Project Objective

The objective of the project was to create and deploy highly available, secure and robust infrastructure for an ecommerce app on AWS. This project prioritized these aspects so
architectural decisions were made to reflect this.

---

## Technologies Used:

- AWS
- Terraform
- Docker
- Helm
- GitHub Actions
- Argo-cd
- Prometheus
- Grafana
- Traefik
- Keda

---

## Project Structure: 

```text
.
|-- compose.yaml
|-- kubernetes
|   |-- application
|   |   |-- api-gateway
|   |   |   |-- deployment.yaml
|   |   |   |-- ingress.yaml
|   |   |   |-- service-account.yaml
|   |   |   `-- service.yaml
|   |   |-- dashboard-api
|   |   |   |-- deployment.yaml
|   |   |   |-- ingress.yaml
|   |   |   |-- service-account.yaml
|   |   |   `-- service.yaml
|   |   |-- inventory-service
|   |   |   |-- deployment.yaml
|   |   |   |-- service-account.yaml
|   |   |   `-- service.yaml
|   |   |-- notification-service
|   |   |   |-- deployment.yaml
|   |   |   |-- service-account.yaml
|   |   |   `-- service.yaml
|   |   |-- order-service
|   |   |   |-- deployment.yaml
|   |   |   |-- service-account.yaml
|   |   |   `-- service.yaml
|   |   |-- payment-service
|   |   |   |-- deployment.yaml
|   |   |   |-- service-account.yaml
|   |   |   `-- service.yaml
|   |   |-- scheduler
|   |   |   |-- deployment.yaml
|   |   |   |-- service-account.yaml
|   |   |   `-- service.yaml
|   |   |-- shipping-service
|   |   |   |-- deployment.yaml
|   |   |   |-- service-account.yaml
|   |   |   `-- service.yaml
|   |   `-- worker
|   |       |-- deployment.yaml
|   |       `-- service-account.yaml
|   |-- argocd
|   |   |-- apps
|   |   |   |-- application-app.yaml
|   |   |   |-- database-app.yaml
|   |   |   `-- infrastructure-app.yaml
|   |   |-- argocd-app.yaml
|   |   `-- root-app.yaml
|   |-- database
|   |   |-- config
|   |   |   |-- postgres-config.yaml
|   |   |   `-- redis-config.yaml
|   |   |-- postgres
|   |   |   |-- secret-provider-class.yaml
|   |   |   |-- service-account.yaml
|   |   |   |-- service.yaml
|   |   |   |-- statefullset.yaml
|   |   |   `-- storage-class.yaml
|   |   `-- redis
|   |       |-- service.yaml
|   |       `-- statefullset.yaml
|   `-- infrastructure
|       |-- issuer.yaml
|       |-- karpenter
|       |-- keda
|       |   |-- scaled-object.yaml
|       |   |-- service-account.yaml
|       |   `-- triggerauth.yaml
|       |-- namespaces
|       |   |-- application.yaml
|       |   |-- argocd-ns.yaml
|       |   |-- database.yaml
|       |   |-- ingress-ns.yaml
|       |   `-- monitoring.yaml
|       |-- network-policy
|       |   |-- api-services-policies.yaml
|       |   |-- default-deny.yaml
|       |   |-- network-policy.yaml
|       |   `-- worker-service.yaml
|       |-- node-pool.yaml
|       |-- priority-class.yaml
|       `-- volumes-snapshot.yaml
|-- renovate.json
|-- scripts
|   `-- localstack-init.sh
|-- services
|   |-- api-gateway
|   |   |-- Dockerfile
|   |   |-- go.mod
|   |   |-- go.sum
|   |   `-- main.go
|   |-- dashboard-api
|   |   |-- Dockerfile
|   |   |-- go.mod
|   |   |-- go.sum
|   |   |-- main.go
|   |   `-- static
|   |       `-- index.html
|   |-- inventory-service
|   |   |-- Dockerfile
|   |   |-- go.mod
|   |   |-- go.sum
|   |   `-- main.go
|   |-- notification-service
|   |   |-- Dockerfile
|   |   |-- go.mod
|   |   |-- go.sum
|   |   `-- main.go
|   |-- order-service
|   |   |-- Dockerfile
|   |   |-- go.mod
|   |   |-- go.sum
|   |   `-- main.go
|   |-- payment-service
|   |   |-- Dockerfile
|   |   |-- go.mod
|   |   |-- go.sum
|   |   `-- main.go
|   |-- scheduler
|   |   |-- Dockerfile
|   |   |-- go.mod
|   |   |-- go.sum
|   |   `-- main.go
|   |-- shipping-service
|   |   |-- Dockerfile
|   |   |-- go.mod
|   |   |-- go.sum
|   |   `-- main.go
|   `-- worker
|       |-- Dockerfile
|       |-- go.mod
|       |-- go.sum
|       `-- main.go
`-- terraform
    |-- backend.tf
    |-- helm-values
    |   |-- argo-cd.yaml
    |   |-- aws-load-balancer-controller.yaml
    |   |-- cert-manager.yaml
    |   |-- ebs-csi.yaml
    |   |-- external-dns.yaml
    |   |-- keda.yaml
    |   |-- secret-store-aws.yaml
    |   |-- secret-store.yaml
    |   |-- snapshot-controller.yaml
    |   |-- traefik.yaml
    |   |-- values-grafana.yaml
    |   `-- values-prom.yaml
    |-- main.tf
    |-- modules
    |   |-- ecr
    |   |   |-- main.tf
    |   |   |-- output.tf
    |   |   `-- variable.tf
    |   |-- eks
    |   |   |-- main.tf
    |   |   |-- output.tf
    |   |   `-- variable.tf
    |   |-- helm
    |   |   |-- main.tf
    |   |   |-- output.tf
    |   |   `-- variable.tf
    |   |-- iam
    |   |   |-- main.tf
    |   |   |-- output.tf
    |   |   `-- variable.tf
    |   |-- irsa
    |   |   |-- main.tf
    |   |   |-- output.tf
    |   |   `-- variable.tf
    |   |-- networking
    |   |   |-- main.tf
    |   |   |-- output.tf
    |   |   `-- variable.tf
    |   |-- security
    |   |   |-- main.tf
    |   |   |-- output.tf
    |   |   `-- variable.tf
    |   `-- sqs
    |       |-- main.tf
    |       |-- output.tf
    |       `-- variable.tf
    |-- output.tf
    |-- provider.tf
    |-- terraform.tfvars
    `-- variable.tf

```

---

# Demo

---


# Images

## App Images

### Orders
<img width="1917" height="1146" alt="Screenshot 2026-09-14 155907" src="https://github.com/user-attachments/assets/59db7c29-831b-4344-a744-bfcef3552a54" />

### Payment
<img width="1917" height="1086" alt="payment-pic" src="https://github.com/user-attachments/assets/7d25d9a2-43d3-467f-a3d0-ef7dc0129e9a" />

### Notification
<img width="1917" height="1087" alt="notification-pic" src="https://github.com/user-attachments/assets/7a8fbdbc-93a9-47ba-8edc-8bb1faeca964" />

### Shipping
<img width="1917" height="1092" alt="shipping-pic" src="https://github.com/user-attachments/assets/c34e8809-303e-46e8-abe0-b1307ec6c003" />


## Monitoring Images

### Argo-cd
<img width="1917" height="1090" alt="argocd-1" src="https://github.com/user-attachments/assets/2afdf60c-ff47-4200-8bab-4c6344a53f85" />

### Grafana
<img width="1916" height="1027" alt="grafana pic" src="https://github.com/user-attachments/assets/69d1cf0f-e371-43b2-860a-c8cd6051af61" />
<img width="1528" height="936" alt="Screenshot 2026-09-17 103449" src="https://github.com/user-attachments/assets/7199aa81-79df-4368-95cf-cb21d8b6a8ef" />


### Prometheus
<img width="1917" height="1142" alt="Screenshot 2026-09-15 145055" src="https://github.com/user-attachments/assets/8b640d52-2b8d-49f4-a8b8-cedf0558567a" />


## Pipeline

<img width="1423" height="290" alt="Pipeline-pic" src="https://github.com/user-attachments/assets/b07003ac-5956-4471-8070-6014889e4529" />

    

    
