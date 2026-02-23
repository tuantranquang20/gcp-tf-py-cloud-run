terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ── Bật tất cả APIs cần thiết ───────────────────────────────
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "eventarc.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "pubsub.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}

# ── Lấy thông tin project ────────────────────────────────────
data "google_project" "project" {}

# ── Modules ──────────────────────────────────────────────────
module "storage" {
  source          = "./modules/storage"
  project_id      = var.project_id
  region          = var.region
  prefix          = var.prefix
  github_sa_email = var.github_sa_email
  depends_on      = [google_project_service.apis]
}

module "artifact_registry" {
  source     = "./modules/artifact_registry"
  project_id = var.project_id
  region     = var.region
  prefix     = var.prefix
  depends_on = [google_project_service.apis]
}

module "cloud_build" {
  source                 = "./modules/cloud_build"
  project_id             = var.project_id
  region                 = var.region
  prefix                 = var.prefix
  bucket_name            = module.storage.artifact_bucket_name
  repo_name              = module.artifact_registry.repo_name
  cloud_run_service_name = var.cloud_run_service_name
  depends_on             = [module.storage, module.artifact_registry]
}

module "cloud_function" {
  source                 = "./modules/cloud_function"
  project_id             = var.project_id
  region                 = var.region
  prefix                 = var.prefix
  bucket_name            = module.storage.artifact_bucket_name
  function_bucket        = module.storage.function_bucket_name
  project_number         = data.google_project.project.number
  cloudbuild_sa          = module.cloud_build.sa_email
  repo_name              = module.artifact_registry.repo_name
  cloud_run_service_name = var.cloud_run_service_name
  cloudbuild_region      = var.region
  depends_on             = [module.cloud_build]
}


module "cloud_run" {
  source                 = "./modules/cloud_run"
  project_id             = var.project_id
  region                 = var.region
  prefix                 = var.prefix
  cloud_run_service_name = var.cloud_run_service_name
  repo_name              = module.artifact_registry.repo_name
  depends_on             = [module.artifact_registry]
}
