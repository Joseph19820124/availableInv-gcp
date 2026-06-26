# ============ Workload Identity Federation:GitHub Actions 免密钥认证 ============
# 让 GitHub Actions 用 OIDC 令牌假设 build SA,无需在 GitHub 存 SA key。

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "availableinv-gh-pool"
  display_name              = "availableInv GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "availableinv-gh"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # 安全:仅允许该仓库的 OIDC 令牌
  attribute_condition = "assertion.repository == \"${var.github_owner}/${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# 允许「该 GitHub 仓库」假设 build SA
resource "google_service_account_iam_member" "wif_build_impersonation" {
  service_account_id = google_service_account.build.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${var.github_repo}"
}

output "wif_provider" {
  description = "GitHub Actions workflow 里 workload_identity_provider 用的值"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "wif_service_account" {
  description = "GitHub Actions 假设的服务账号"
  value       = google_service_account.build.email
}
