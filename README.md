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
| CodePipeline(编排器)| **GitHub Actions**(编排器)|
| CodeBuild | GitHub Actions runner 里 `docker build` |
| CodeDeploy(ECS 部署)| **Cloud Deploy**(渐进式发布)|
| Terraform S3 + DynamoDB | **Terraform GCS backend** |

```
GitHub push ─▶ GitHub Actions (.github/workflows/deploy.yml)
                 ├─ WIF 免密钥认证到 GCP
                 ├─ docker build → push Artifact Registry
                 └─ gcloud deploy releases create ─▶ Cloud Deploy ─▶ Cloud Run (rollout)
```

> CI/CD 编排用 **GitHub Actions**(取代 AWS 的 CodePipeline)。GitHub Actions 负责 Source+Build 并"交棒"给 **Cloud Deploy** 做发布;Cloud Deploy 再 rollout 到 **Cloud Run**。

## 文件

- `Dockerfile` / `build.gradle` / `src/` —— Java 服务(同 AWS 版)
- `.github/workflows/deploy.yml` —— **GitHub Actions** 编排:WIF 认证 → 构建推 AR → 建 Cloud Deploy 发布
- `skaffold.yaml` + `run-service.yaml` —— Cloud Deploy 渲染并部署到 Cloud Run 的清单
- `terraform/` —— Artifact Registry、Cloud Deploy pipeline/target、服务账号/IAM、**Workload Identity Federation**(给 GitHub Actions 免密钥认证)

## 部署

```bash
cd terraform
terraform init
terraform apply        # 建 AR / Cloud Deploy / SA / IAM / WIF(不含 Cloud Run 服务本体)
```

之后每次 `git push` 到 `main`,GitHub Actions 自动完成构建+部署。

> - Cloud Run 服务本体由 **Cloud Deploy 的首次发布**创建并接管(不由 Terraform 管理,避免二者打架)。
> - GitHub Actions 用 **Workload Identity Federation 免密钥**认证,**无需在 GitHub 存任何 SA key/secret**;provider 与 SA 已硬编码在 workflow(均非机密)。
