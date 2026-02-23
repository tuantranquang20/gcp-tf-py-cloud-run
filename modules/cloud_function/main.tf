data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/source"
  output_path = "/tmp/${var.prefix}-cloud-function.zip"
}
# ── Eventarc Service Agent ───────────────────────────────────
# Google tự tạo SA này khi bật Eventarc API
# Cần cấp quyền thủ công vì đôi khi không tự propagate

resource "google_project_iam_member" "eventarc_service_agent" {
  project = var.project_id
  role    = "roles/eventarc.serviceAgent"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-eventarc.iam.gserviceaccount.com"
}

# Eventarc Service Agent cũng cần quyền act as function SA
resource "google_project_iam_member" "eventarc_act_as_function_sa" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-eventarc.iam.gserviceaccount.com"
}

resource "google_storage_bucket_object" "function_source" {
  name   = "cloud-function-${data.archive_file.function_zip.output_md5}.zip"
  bucket = var.function_bucket
  source = data.archive_file.function_zip.output_path
}

resource "google_service_account" "function_sa" {
  account_id   = "${var.prefix}-function-sa"
  display_name = "${var.prefix} Cloud Function SA"
}

resource "google_project_iam_member" "function_cloudbuild_editor" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

resource "google_project_iam_member" "function_eventarc_receiver" {
  project    = var.project_id
  role       = "roles/eventarc.eventReceiver"
  member     = "serviceAccount:${google_service_account.function_sa.email}"
  # FIX #2: Đảm bảo IAM được cấp trước khi tạo Function
  depends_on = [google_project_iam_member.function_cloudbuild_editor]
}

resource "google_project_iam_member" "function_run_invoker" {
  project    = var.project_id
  role       = "roles/run.invoker"
  member     = "serviceAccount:${google_service_account.function_sa.email}"
  depends_on = [google_project_iam_member.function_eventarc_receiver]
}

resource "google_project_iam_member" "function_ar_reader" {
  project    = var.project_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.function_sa.email}"
  depends_on = [google_project_iam_member.function_run_invoker]
}

# FIX #2: GCS SA cần pubsub.publisher — tạo TRƯỚC Cloud Function
data "google_storage_project_service_account" "gcs_sa" {}

resource "google_project_iam_member" "gcs_pubsub_publisher" {
  project    = var.project_id
  role       = "roles/pubsub.publisher"
  member     = "serviceAccount:${data.google_storage_project_service_account.gcs_sa.email_address}"
  depends_on = [google_project_iam_member.function_ar_reader]
}

resource "google_service_account_iam_member" "function_impersonate_cloudbuild" {
  service_account_id = "projects/terraform-gcp-450004/serviceAccounts/${var.cloudbuild_sa}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.function_sa.email}"
}

# Quyền đọc file zip từ bucket (GCS Viewer)
resource "google_project_iam_member" "function_gcs_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# Quyền tạo và quản lý tiến trình build (Cloud Build Editor)
resource "google_project_iam_member" "function_build_editor" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

resource "google_cloudfunctions2_function" "deploy_trigger" {
  name        = "${var.prefix}-deploy-trigger"
  location    = var.region
  description = "Trigger Cloud Build khi có .zip mới upload lên GCS"

  build_config {
    runtime     = "python311"
    entry_point = "trigger_build"
    source {
      storage_source {
        bucket = var.function_bucket
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    service_account_email          = google_service_account.function_sa.email
    min_instance_count             = 0
    max_instance_count             = 3
    timeout_seconds                = 240 
    available_memory               = "512Mi" 
    all_traffic_on_latest_revision = true

    environment_variables = {
      PROJECT_ID   = var.project_id
      REGION       = var.region
      REPO_NAME     = var.repo_name
      SERVICE_NAME  = var.cloud_run_service_name
      CLOUDBUILD_SA = var.cloudbuild_sa
    }
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.storage.object.v1.finalized"
    retry_policy          = "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = google_service_account.function_sa.email
    event_filters {
      attribute = "bucket"
      value     = var.bucket_name
    }
  }

  depends_on = [
    google_project_iam_member.eventarc_service_agent,
    google_project_iam_member.eventarc_act_as_function_sa,
    google_project_iam_member.gcs_pubsub_publisher,
      google_project_iam_member.function_ar_reader,
    google_project_iam_member.function_run_invoker,
    # Chú ý: Cần đảm bảo function_sa có quyền Storage Object Viewer và Cloud Build Editor
    google_project_iam_member.function_gcs_viewer,     # Quyền đọc file zip từ bucket
    google_project_iam_member.function_build_editor,   # Quyền gọi API create_build
    google_project_iam_member.function_eventarc_receiver,
  ]
}
