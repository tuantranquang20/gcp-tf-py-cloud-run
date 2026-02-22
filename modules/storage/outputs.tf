output "artifact_bucket_name" {
  value = google_storage_bucket.artifacts.name
}
output "function_bucket_name" {
  value = google_storage_bucket.function_source.name
}
