# modules/cloud_build/main.tf
# Chỉ giữ Service Account + IAM + Artifact Registry
# KHÔNG tạo trigger nữa

resource "google_service_account" "cloudbuild_sa" {
  account_id   = "${var.prefix}-cloudbuild-sa"
  display_name = "${var.prefix} Cloud Build SA"
}

resource "google_project_iam_member" "cloudbuild_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_act_as" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_storage_bucket_iam_member" "cloudbuild_gcs_reader" {
  bucket = var.bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_storage_bucket_iam_member" "cloudbuild_gcs_writer" {
  bucket = var.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}
