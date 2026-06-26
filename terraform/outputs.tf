output "artifact_registry" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}"
}

output "image" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${var.app_name}/${var.app_name}"
}

output "delivery_pipeline" {
  value = google_clouddeploy_delivery_pipeline.pipeline.name
}

output "deploy_target" {
  value = google_clouddeploy_target.prod.name
}

output "run_service_account" {
  value = google_service_account.run.email
}

output "build_service_account" {
  value = google_service_account.build.email
}

output "deploy_service_account" {
  value = google_service_account.deploy.email
}
