# availableInv (GCP)

把 [availableInv](https://github.com/Joseph19820124/availableInv) 这套从 **AWS(ECS + CodePipeline/CodeBuild)** 迁移到 **GCP**。Java 服务代码完全不变,只换了基础设施与 CI/CD。

> 迁移动机:AWS 账号的 CodeBuild 并发配额被卡在 0,流水线 Build 阶段跑不动。GCP 的 Cloud Build 无此限制,且本身就部署在 GCP 上。

## 服务

Spring Boot 3 / Java 17,端口 8080。

| 路由 | 响应 |
|------|------|
| `GET /health` | `{"status":"UP"}` |
| `GET /inventory/available?sku=<id>` | `{"sku":"...","availableQuantity":42,"source":"fake"}` |

## 架构(AWS → GCP)

| AWS | GCP |
|-----|-----|
| ECR | **Artifact Registry** |
| ECS Fargate + ALB | **Cloud Run** |
| CodePipeline + CodeBuild | **Cloud Build** |
| CodeDeploy(ECS 部署)| **Cloud Deploy**(渐进式发布)|
| Terraform S3 + DynamoDB | **Terraform GCS backend** |

```
GitHub push ─▶ Cloud Build ─▶ build image ─▶ Artifact Registry
                    └─▶ Cloud Deploy release ─▶ Cloud Run (rollout)
```

## 文件

- `Dockerfile` / `build.gradle` / `src/` —— Java 服务(同 AWS 版)
- `cloudbuild.yaml` —— Cloud Build:构建 + 推 AR + 创建 Cloud Deploy 发布
- `clouddeploy` 流水线/目标 —— 由 `terraform/` 管理
- `skaffold.yaml` + `run-service.yaml` —— Cloud Deploy 渲染并部署到 Cloud Run 的清单
- `terraform/` —— Artifact Registry、Cloud Deploy pipeline/target、服务账号/IAM、(可选)Cloud Build 触发器

## 部署

```bash
cd terraform
terraform init
terraform apply        # 建 AR / Cloud Deploy / SA / IAM(不含 Cloud Run 服务本体)

# 构建并推首个镜像,然后用 Cloud Deploy 发布(Cloud Run 服务由此创建)
gcloud builds submit --config ../cloudbuild.yaml ..   # 或本地 docker build & push 后手动建 release
```

> Cloud Run 服务本体由 **Cloud Deploy 的首次发布**创建并接管(不由 Terraform 管理,避免二者打架)。

## ⚠️ GitHub 自动触发的一次性手动步骤

`push → Cloud Build 自动跑` 需要先在控制台把仓库连接到 **Cloud Build GitHub App**(2nd-gen connection,一次性 OAuth)。连接好后,把 `terraform/variables.tf` 的 `enable_github_trigger=true` 并填 `cloudbuild_connection`,再 `terraform apply` 即可启用触发器。
