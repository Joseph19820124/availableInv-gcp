data "google_project" "this" {
  project_id = var.project_id
}

# 确保 Cloud Deploy API 启用(run/cloudbuild/artifactregistry 已启用)
resource "google_project_service" "clouddeploy" {
  service            = "clouddeploy.googleapis.com"
  disable_on_destroy = false
}

# ---------------- Artifact Registry(等价 ECR)----------------
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = var.app_name
  format        = "DOCKER"
  description   = "availableInv images"
}

# ---------------- Service Accounts ----------------
# Cloud Run 运行身份
resource "google_service_account" "run" {
  account_id   = "${var.app_name}-run"
  display_name = "availableInv Cloud Run runtime"
}

# Cloud Deploy 执行身份(渲染 + 部署到 Cloud Run)
resource "google_service_account" "deploy" {
  account_id   = "${var.app_name}-deploy"
  display_name = "availableInv Cloud Deploy executor"
}

# Cloud Build 身份(构建 + 推 AR + 建 Cloud Deploy 发布)
resource "google_service_account" "build" {
  account_id   = "${var.app_name}-build"
  display_name = "availableInv Cloud Build"
}

# ---- deploy SA 权限 ----
resource "google_project_iam_member" "deploy_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.deploy.email}"
}

resource "google_project_iam_member" "deploy_jobrunner" {
  project = var.project_id
  role    = "roles/clouddeploy.jobRunner"
  member  = "serviceAccount:${google_service_account.deploy.email}"
}

resource "google_project_iam_member" "deploy_storage" {
  project = var.project_id
  role    = "roles/storage.admin" # Cloud Deploy 渲染产物桶
  member  = "serviceAccount:${google_service_account.deploy.email}"
}

# deploy SA 需能以 run 运行身份部署服务
resource "google_service_account_iam_member" "deploy_actas_run" {
  service_account_id = google_service_account.run.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deploy.email}"
}

# ---- build SA 权限 ----
resource "google_project_iam_member" "build_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.build.email}"
}

resource "google_project_iam_member" "build_releaser" {
  project = var.project_id
  role    = "roles/clouddeploy.releaser"
  member  = "serviceAccount:${google_service_account.build.email}"
}

resource "google_project_iam_member" "build_logs" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.build.email}"
}

# build SA 创建发布时需能以 deploy SA 执行
resource "google_service_account_iam_member" "build_actas_deploy" {
  service_account_id = google_service_account.deploy.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.build.email}"
}

# ---------------- Cloud Deploy(等价 CodePipeline+Deploy)----------------
resource "google_clouddeploy_target" "prod" {
  location = var.region
  name     = "${var.app_name}-prod"

  run {
    location = "projects/${var.project_id}/locations/${var.region}"
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.deploy.email
  }

  depends_on = [google_project_service.clouddeploy]
}

resource "google_clouddeploy_delivery_pipeline" "pipeline" {
  location = var.region
  name     = "${var.app_name}-pipeline"

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.prod.name
    }
  }

  depends_on = [google_project_service.clouddeploy]
}

# ---------------- Cloud Build 触发器(GitHub push 自动跑)----------------
# 需先在控制台连接 GitHub(Cloud Build GitHub App / 2nd-gen connection),
# 然后 enable_github_trigger=true 并填 cloudbuild_connection。
resource "google_cloudbuildv2_repository" "repo" {
  count             = var.enable_github_trigger ? 1 : 0
  name              = var.github_repo
  location          = var.region
  parent_connection = var.cloudbuild_connection
  remote_uri        = "https://github.com/${var.github_owner}/${var.github_repo}.git"
}

resource "google_cloudbuild_trigger" "github" {
  count           = var.enable_github_trigger ? 1 : 0
  name            = "${var.app_name}-trigger"
  location        = var.region
  service_account = google_service_account.build.id
  filename        = "cloudbuild.yaml"

  repository_event_config {
    repository = google_cloudbuildv2_repository.repo[0].id
    push {
      branch = var.github_branch
    }
  }
}
