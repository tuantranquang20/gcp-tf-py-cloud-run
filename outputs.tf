output "artifact_bucket" {
  value       = module.storage.artifact_bucket_name
  description = "GCS bucket để upload .zip từ GitHub Actions"
}

output "cloud_run_url" {
  value       = module.cloud_run.service_url
  description = "URL Cloud Run service"
}

output "artifact_registry_repo" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${module.artifact_registry.repo_name}"
  description = "Artifact Registry repository URL"
}

output "github_actions_config" {
  value = {
    bucket_name = module.storage.artifact_bucket_name
    region      = var.region
    project_id  = var.project_id
  }
  description = "Các giá trị cần thêm vào GitHub Actions secrets/variables"
}
