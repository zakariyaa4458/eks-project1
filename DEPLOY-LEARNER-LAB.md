# Deploy Learner Lab ra Internet

Bản này dùng hai Terraform state trong cùng bucket: terraform/ tạo AWS; terraform/platform/ cài EBS CSI, Argo CD, secrets và root-app. Script điều phối cả hai, không cần cài thủ công hay port-forward.

Terraform tạo public Network Load Balancer → NodePort 30086 → dashboard-api. Dashboard proxy /auth và /api tới gateway, nên trình duyệt chỉ cần một URL. Không cần domain hoặc AWS Load Balancer Controller/IRSA mới. Giữ 3 node, 2 replica cho các service như hiện tại và PVC EBS cho PostgreSQL/Redis.

Đây là HTTP cho demo. Login của tác giả vẫn chấp nhận thông tin tùy ý. Người dùng đã apply thành công và mở được dashboard public trong Lab. Hướng dẫn từng lệnh nằm trong HUONG-DAN-DEPLOY-LEARNER-LAB.txt.

## Chạy từ CloudShell

Sau khi xóa xong bản cũ, commit/push code mới từ máy Windows rồi chạy:

```bash
cd ~/eks-deploy
git pull --ff-only
bash scripts/deploy-lab.sh infra
```

Script tự init và apply AWS; tự tìm bucket state cũ từ backend hoặc .lab-state-bucket, nếu không có thì dùng eks-project1-tfstate-425959969184-us-east-1. Terraform provider đặt trong /tmp để tránh đầy thư mục home. Bucket state được chặn public và bật versioning.

Cập nhật ba GitHub Actions secrets của phiên Lab. Trong Actions chạy app-cd pipeline trên main, đợi xanh. Không push thêm commit lúc workflow đang build. Sau đó:

```bash
git pull --ff-only
bash scripts/deploy-lab.sh platform
```

Script init/apply state Kubernetes, cài Helm chart EBS CSI controller hostNetwork=true, Argo CD namespace argo-cd đúng RBAC, tạo secrets và root-app. Không cài EBS managed add-on song song với Helm. Mật khẩu PostgreSQL được Terraform tạo/lưu trong Secrets Manager, Kubernetes nhận giá trị tương ứng. Credentials SQS lấy từ phiên AWS đang chạy, không ghi vào Git. Secret/credentials có trong Terraform state nên giữ bucket state private.

Cuối script in URL http://...elb.amazonaws.com. Argo tự đồng bộ ứng dụng; chờ workload khởi động rồi mở URL đó trên bất kỳ máy nào. Không cần script mở localhost.

Nếu muốn tạo AWS và platform liên tục trước khi build image:

```bash
bash scripts/deploy-lab.sh all
```

Sau đó vẫn phải chạy app-cd pipeline để đưa image vào ECR. Đến khi image được publish và manifest được cập nhật, ứng dụng mới chạy được. Apply thành công chưa đồng nghĩa Argo đã hoàn tất deploy.

## Chạy bằng GitHub Actions

Quy trình không cần lệnh CloudShell nằm trong [HUONG-DAN-GITHUB-ACTIONS.txt](HUONG-DAN-GITHUB-ACTIONS.txt): bật workflow, cập nhật ba secrets, dùng đúng TF_STATE_BUCKET rồi chạy infra → app-cd → platform. Runner tự chuẩn bị Terraform, kubectl và Python, kiểm tra danh tính voclabs; Summary hiển thị URL dashboard. Các workflow infra/app-cd/destroy dùng chung concurrency để tránh build/deploy/xóa đồng thời.

Workflow deploy infrastructure đã được chuyển từ validate-only sang apply thủ công. Có thể dùng các stage infra/platform/all/refresh. Workflow destroy infrastructure gọi cùng script dọn workload/EBS trước Terraform destroy.

Stage all tạo AWS và platform, không build image. Destroy có lựa chọn delete_state_bucket để xóa thêm bucket chuyên dụng và lịch sử state; mặc định giữ bucket. Trạng thái Disabled phải bật bằng Enable workflow trên GitHub.

Nếu dùng bucket khác tên mặc định, đặt repository variable TF_STATE_BUCKET bằng tên trong .lab-state-bucket (CloudShell). CloudShell và Actions phải dùng cùng bucket; không dùng hai state khác nhau cho cùng cluster.

Nếu cluster được tạo bằng CloudShell trước, chạy platform bằng CloudShell cùng danh tính voclabs. GitHub có thể không có quyền Kubernetes nếu dùng một IAM principal khác với principal tạo cluster; phải cấp EKS access cho principal đó trước.

## Phiên Lab mới

```bash
cd ~/eks-deploy
bash scripts/deploy-lab.sh refresh
```

Lệnh này cập nhật Secret credentials qua Terraform và restart 4 Deployment gọi SQS. Cập nhật ba GitHub secrets trước lần build tiếp theo. Không đổi mật khẩu PostgreSQL nếu vẫn giữ platform state.

Không chạy load-lab-secrets.py song song nữa: secrets hiện thuộc Terraform. Không dùng lệnh cài Argo/EBS bằng tay từ hướng dẫn cũ.

## Xóa bản mới

```bash
cd ~/eks-deploy
bash scripts/deploy-lab.sh destroy
```

Script dừng các Argo Applications, xóa namespace ứng dụng/database, đợi PV biến mất trong khi EBS CSI còn chạy; sau đó destroy platform rồi destroy AWS. ECR force_delete xóa cả image. Secret bị xóa không có thời gian khôi phục. Bucket state được giữ lại để quản lý lịch sử; chỉ xóa riêng bucket của dự án sau khi destroy hoàn tất nếu không cần lịch sử.

Để xóa cả bucket state của bản deploy hiện tại, chạy `bash scripts/destroy-lab-all.sh`. Script chỉ chấp nhận bucket `eks-project1-tfstate-425959969184-us-east-1`, xóa cả các phiên bản/object sau khi hai phần Terraform destroy thành công. Dừng các workflow đang deploy/build trước khi chạy. Lệnh này xóa dữ liệu ứng dụng và lịch sử state; giữ LabRole và tài nguyên ngoài bản deploy hiện tại.

Bản cũ cài bằng kubectl/managed add-on cần được dọn theo hướng dẫn cũ trước khi áp dụng bản này. Script không tự nhận quản lý tài nguyên cài tay hoặc thay mật khẩu database đang có dữ liệu. Nếu báo tên resource đã tồn tại, dừng và xử lý state/import; không tạo thêm bucket để né lỗi.
