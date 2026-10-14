# Cá nhân hóa để triển khai trên AWS

## Các giá trị đã cá nhân hóa

- AWS account: `241533156847`; region: `us-east-1`.
- ECR dùng prefix `eks-project1` cho 9 service.
- Terraform tạo IAM roles/OIDC theo cấu hình hiện có, thay cấu hình Learner Lab `LabRole`.
- Terraform provider gắn tags mặc định: `Project=eks-project1`, `Owner=anhhao1712`, `Environment=learning`, `ManagedBy=Terraform`.
- GitHub Actions tạo S3 state bucket ở lần chạy hạ tầng đầu tiên; bật versioning, chặn public access, mã hóa AES256 và tags. Bucket được giữ lại khi destroy thông thường.
- Bỏ Route 53, ExternalDNS, cert-manager, hostname và TLS theo domain. Các Ingress không gắn hostname; Traefik dùng địa chỉ DNS AWS cấp cho Load Balancer.
- Giữ các thành phần ứng dụng/kiến trúc chính, gồm EKS, Traefik, Argo CD, Karpenter, Prometheus, Grafana, KEDA, EBS CSI và 9 service.

## Cách GitHub Actions nhận quyền AWS

Các workflow hiện dùng credentials tạm thời từ AWS IAM Identity Center qua ba GitHub repository secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`. AWS session hết hạn thì cần lấy bộ credentials mới và cập nhật đủ ba secrets trước khi chạy workflow. Workflow không tạo GitHub OIDC role; không lưu credentials trong source hoặc GitHub Variables.

Nếu quyền `SystemAdministrator` không cho tạo IAM roles/policies/OIDC provider hoặc các tài nguyên EKS cần thiết, Terraform sẽ dừng ở bước bị AWS từ chối. Khi đó cần nhờ chủ account cấp quyền phù hợp.

## Quy trình deploy

1. Thêm/cập nhật ba repository secrets nêu trên.
2. Chạy `deploy infrastructure` với branch `main`, stage `all` để Terraform tạo bucket state, AWS infrastructure và platform.
3. Chạy `app-cd pipeline` trên `main` để build/push 9 images và cập nhật manifest.
4. Chờ Argo CD đồng bộ. Dashboard URL được in ở workflow summary; host là DNS của Load Balancer AWS.
5. Khi muốn dọn hạ tầng, chạy `destroy infrastructure`. Mặc định state bucket được giữ lại; chỉ chọn xóa bucket nếu muốn xóa cả lịch sử Terraform state.

Đây là các thay đổi cấu hình. Chưa có workflow nào được chạy trên AWS account thật và chưa có tài nguyên AWS nào được tạo bởi việc sửa code.
