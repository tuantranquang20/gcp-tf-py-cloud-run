output "function_name" {
  value = google_cloudfunctions2_function.deploy_trigger.name
}
output "function_uri" {
  value = google_cloudfunctions2_function.deploy_trigger.service_config[0].uri
}
