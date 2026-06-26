variable "project_id" {
  type    = string
  default = "gwsjoseph0326"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "app_name" {
  type    = string
  default = "availableinv"
}

# CI/CD —— GitHub 源
variable "github_owner" {
  type    = string
  default = "Joseph19820124"
}

variable "github_repo" {
  type    = string
  default = "availableInv-gcp"
}

variable "github_branch" {
  type    = string
  default = "^main$"
}

# GitHub 触发器需要先在控制台连接 Cloud Build GitHub App(一次性 OAuth);
# 连接好之前先保持 false,避免 apply 失败。
variable "enable_github_trigger" {
  type    = bool
  default = false
}

# 已连接好的 Cloud Build 2nd-gen connection 名称(enable_github_trigger=true 时用)
variable "cloudbuild_connection" {
  type    = string
  default = ""
}
