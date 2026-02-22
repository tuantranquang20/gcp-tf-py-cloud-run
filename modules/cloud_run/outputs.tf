output "service_url" {
  value = google_cloud_run_v2_service.app.uri
}
output "service_name" {
  value = google_cloud_run_v2_service.app.name
}
output "sa_email" {
  value = google_service_account.run_sa.email
}
