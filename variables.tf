variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "Region triển khai"
}

variable "prefix" {
  type        = string
  default     = "myapp"
  description = "Prefix cho tất cả resource"
}

variable "github_sa_email" {
  type        = string
  description = "Email của Service Account đã cấp cho GitHub Actions (đã setup bằng tay)"
}
//https://iam.googleapis.com/projects/501313044608/locations/global/workloadIdentityPools/ga-pool/providers/ga-provider
variable "cloud_run_service_name" {
  type        = string
  default     = "my-app"
  description = "Tên Cloud Run service"
}

variable "trigger_id" {
  type        = string
}

