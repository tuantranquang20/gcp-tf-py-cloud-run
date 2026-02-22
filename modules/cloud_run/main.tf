resource "google_service_account" "run_sa" {
  account_id   = "${var.prefix}-run-sa"
  display_name = "${var.prefix} Cloud Run SA"
}

resource "google_project_iam_member" "run_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_project_iam_member" "run_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.run_sa.email}"
}

# Tạo Cloud Run service với placeholder image
# Image thực sẽ được update bởi Cloud Build sau mỗi lần deploy
resource "google_cloud_run_v2_service" "app" {
  name     = var.cloud_run_service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.run_sa.email

    containers {
      # Placeholder image — Cloud Build sẽ thay thế bằng image thực
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      env {
        name  = "APP_VERSION"
        value = "initial"
      }

      env {
        name  = "ENVIRONMENT"
        value = "production"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      liveness_probe {
        http_get { path = "/health" }
        initial_delay_seconds = 10
        period_seconds        = 30
        failure_threshold     = 3
      }

      startup_probe {
        http_get { path = "/health" }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 10
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }
  }

  # Quan trọng: Không để Terraform override image sau khi Cloud Build đã deploy
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      template[0].containers[0].env,
      client,
      client_version,
    ]
  }
}

# Cho phép public truy cập
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
