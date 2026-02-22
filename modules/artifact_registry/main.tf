resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "${var.prefix}-repo"
  format        = "DOCKER"
  description   = "Docker images for ${var.prefix}"
}
