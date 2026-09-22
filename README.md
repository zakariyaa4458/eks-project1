

# Ecommerce App - AWS EKS Dev-Ops Deployment

A dev-ops project that deploys 9 services as part of an ecommerce app to AWS using Terraform, Docker, Helm and GitHub Actions.

---

## Project Objective

The objective of the project was to create and deploy highly available, secure and robust infrastructure for an ecommerce app on AWS. This project prioritized these aspects so
architectural decisions were made to reflect this.

## About the app

This is an ecommerce app that it written in Golang, where a user can browse products and place an order through a web interface. When they submit an order, the application checks whether the requested products are available, processes the payment, creates the order and begins processing it in the background. The user can then see the order and its current status through the dashboard as it progresses through stages such as pending, confirmed, processing, shipped and delivered.

---

## Architecture Diagram
<img width="8920" height="9798" alt="eks4 drawio" src="https://github.com/user-attachments/assets/0aacf3cf-93d7-4fa2-96f4-d223103fdf6a" />



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

# Architectual decisions

## Microservices Architecture and Independent Deployment
 I decided to separate  the application into services such as Order, Payment, Inventory, Notification, Shipping and Worker and give each service its own ECR repository. This allows services to be developed, deployed and scaled independently, although it introduces more networking and operational complexity. This allows me to change and scale high-demand parts of the application independently, enabling faster releases and avoiding the cost of scaling the entire application for one busy component.

## Multi-AZ Architecture for High Availability
I used 3 availability zones with 2 Subnets (private and public) in each AZ to allow for high availability, this improves resilience because losing one AZ doesn't necessarily take down the application. To increase availability I could have used a multi-region zone setup because this would mean if the whole London region became unavailable the app could survive, however this incurs great costs as it means individual parts of the infrastructure would effectively by needed twice. e.g. EKS, nodes, load-balancer etc, so I decided to opt for the multi AZ in 1 region approach.

## KEDA Event-Driven vs Resource-Based Autoscaling

I chose KEDA for the worker service because KEDA supports event-driven autoscaling. Rather than scaling based purely on CPU or memory utilisation, I can scale workers based on the actual workload, such as the number of messages waiting in the SQS queue. This better represents demand on an e-commerce platform. During periods such as Black Friday, Christmas or promotional sales, order volumes could increase significantly, causing the queue to grow. KEDA can respond by increasing the number of worker pods. During quieter periods, it can reduce the number of workers, helping reduce unnecessary compute usage." One reason I implemented KEDA over similar alternatives such as HPA is because it scales based on events as opposed to cpu usage. With CPU-based autoscaling, a large volume of malicious HTTP traffic could increase CPU utilisation and trigger additional replicas, potentially increasing infrastructure costs without corresponding to genuine customer demand. My KEDA configuration instead scales the Worker based on orders entering the SQS queue.

## Separation of infrastructure and app pipeline
I decided to create two pipelines one for infrastructure and one for app, this is because creating two prevents new changes in the terraform infrastructure to create new images unnecessarily which would cause the ECR repository to become unnecessarily filled with new images when the app remains the same. This allows for easier rollback as well as the images will only be created if a new app feature or an adjustment in the app is made.

## Managing Secrets
I implemented secret store csi driver and secret store csi driver provider aws. The secret store driver essentially mounts the secrets into the pod in kubernetes whilst secret store csi driver provider aws is essentially the plug-in which authenticates to aws and retrieves the secret for the aws secrets manager. In terms of secret rotation when a secret is rotated in AWS Secrets Manager, the new value is retrieved by the Secrets Store CSI Driver and AWS Provider and synchronized with the Kubernetes Secret. However, environment variables in already running Pods do not automatically change, so the affected Pods must be restarted or rolled out to load the new value. For database passwords, the actual password in the database must also be changed to match the newly rotated secret.

---

# Demo
https://youtu.be/0FEr9NLxj1M

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

---

## Future Improvements

### Database Migrations
A future improvement would be to introduce a dedicated automated database migration process for managing PostgreSQL schema changes. Version-controlled migrations could be executed using a Kubernetes Job as part of the deployment process before a new application version becomes active. Since multiple services share the same database, migrations would be designed to remain backwards compatible, allowing both old and new application versions to operate during rolling deployments. Destructive changes, such as removing or renaming columns, could then be performed in a later migration after older application versions are no longer running. This would also improve rollback safety, as Argo CD could restore a previous application version without immediately becoming incompatible with the updated database schema.

### Managed Databases
To further improve this project I could implement database management services such as Amazon RDS or Elasticache to manage the responsibilities. For example provisioning the database server, replacing failed infrastructure, automated backups, patching options, monitoring integration and Multi-AZ failover when configured. This would improve the robustness of the infrastructure in many ways providing easier scaling, maintenance and patching as AWS would handle much of this, therefore reducing the amount of manual maintenance required compared with operating the database yourself inside Kubernetes. This would allow for less downtime and a faster and smoother service which would facilitate for greater revenue generation.

## Security Measures Implemented

- GitHub Actions OIDC — Used short-lived AWS credentials instead of storing long-lived AWS access keys in GitHub.
  
- IAM Roles for Service Accounts (IRSA) — Kubernetes workloads such as ExternalDNS, the EBS CSI Driver, KEDA and other AWS-integrated components receive AWS permissions through dedicated IAM roles rather than shared credentials.
  
- Least-privilege IAM policies — IAM roles were restricted to the AWS actions and resources required by each component, reducing the impact of a compromised workload.
  
- AWS Secrets Manager — Database credentials and other sensitive values were kept outside application code and Kubernetes manifests.
  
- Secrets Store CSI Driver + AWS Provider — Secrets were securely retrieved from Secrets Manager and delivered to Kubernetes workloads rather than being hardcoded into deployment files.
  
- Private worker nodes — EKS worker nodes and application workloads were placed in private subnets rather than being directly exposed to the Internet.
  
- Security Groups — Network access between the EKS control plane and worker nodes was restricted to required communication, including ports such as 443, 10250, 9402, and 9443.
  
- Secure container configuration — Workloads used controls such as runAsNonRoot, dropped Linux capabilities, allowPrivilegeEscalation: false, seccomp: RuntimeDefault, and read-only root filesystems where applicable.
  
- Trivy container scanning — Docker images were scanned for HIGH and CRITICAL vulnerabilities before being pushed/deployed, allowing insecure builds to fail the pipeline.
  
- Checkov security scanning — Terraform and Kubernetes configurations were statically analysed for security and configuration problems before deployment.
TLS/HTTPS — Traefik and cert-manager were used to provide encrypted HTTPS access to externally exposed application endpoints.

- Encrypted EBS storage — Persistent PostgreSQL and Redis data used encrypted EBS-backed storage.
  
- VPC Flow Logs — Network traffic metadata was captured for monitoring and auditing, with the CloudWatch log group protected using KMS encryption.
  
- Private/public subnet separation — Internet-facing infrastructure such as the load balancer was separated from application worker nodes and workloads running in private subnets.
  
- Automated deployment gates — Failed tests or security scans prevented the deployment pipeline from progressing, reducing the chance of vulnerable or broken application versions reaching the cluster.
    

    
