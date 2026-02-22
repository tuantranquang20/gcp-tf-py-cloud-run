# ── Bucket chứa artifact .zip từ GitHub Actions ─────────────
resource "google_storage_bucket" "artifacts" {
  name                        = "${var.prefix}-artifacts-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  # Tự động xóa artifact cũ hơn 30 ngày
  lifecycle_rule {
    condition { age = 30 }
    action { type = "Delete" }
  }

  # Giữ tối đa 10 phiên bản của mỗi file
  lifecycle_rule {
    condition { num_newer_versions = 10 }
    action { type = "Delete" }
  }
}

# ── Bucket chứa source code của Cloud Function ───────────────
resource "google_storage_bucket" "function_source" {
  name                        = "${var.prefix}-function-source-${var.project_id}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}

# ── Quyền cho GitHub Actions SA upload artifact ─────────────
resource "google_storage_bucket_iam_member" "github_writer" {
  bucket = google_storage_bucket.artifacts.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.github_sa_email}"
}

# ── Quyền cho GitHub Actions SA đọc/ghi latest.json ─────────
resource "google_storage_bucket_iam_member" "github_reader" {
  bucket = google_storage_bucket.artifacts.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${var.github_sa_email}"
}
