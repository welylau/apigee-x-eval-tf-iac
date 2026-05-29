terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.33.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.33.0"
    }
  }
}

variable "project_id" {
  description = "Your GCP Project ID"
  type        = string
}

variable "region" {
  description = "Region for Apigee and Subnets"
  type        = string
  default     = "us-central1"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# ------------------------------------------------------------------------------
# 1. NETWORKING (VPC, Subnet, Service Networking)
# ------------------------------------------------------------------------------

resource "google_compute_network" "apigee_vpc" {
  name                    = "apigee-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "apigee_subnetwork" {
  name          = "apigee-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.apigee_vpc.id
}

resource "google_compute_global_address" "apigee_peering_range" {
  name          = "apigee-peering-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 22
  network       = google_compute_network.apigee_vpc.id
}

resource "google_service_networking_connection" "apigee_vpc_connection" {
  network                 = google_compute_network.apigee_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.apigee_peering_range.name]
}

# ------------------------------------------------------------------------------
# 2. APIGEE X EVALUATION PROVISIONING
# ------------------------------------------------------------------------------

resource "google_apigee_organization" "apigee_org" {
  project_id         = var.project_id
  analytics_region   = var.region
  billing_type       = "EVALUATION"
  authorized_network = google_compute_network.apigee_vpc.id

  depends_on = [google_service_networking_connection.apigee_vpc_connection]
}

resource "google_apigee_instance" "apigee_instance" {
  name     = "apigee-eval-instance"
  location = var.region
  org_id   = google_apigee_organization.apigee_org.id
}

resource "google_apigee_environment" "apigee_env" {
  name           = "eval"
  description    = "Apigee Evaluation Environment"
  org_id         = google_apigee_organization.apigee_org.id
  api_proxy_type = "PROGRAMMABLE"
}

resource "google_apigee_instance_attachment" "env_to_instance" {
  instance_id = google_apigee_instance.apigee_instance.id
  environment = google_apigee_environment.apigee_env.name
}

# ------------------------------------------------------------------------------
# 3. EXTERNAL LOAD BALANCER & PSC NEG
# ------------------------------------------------------------------------------

resource "google_compute_global_address" "lb_external_ip" {
  name = "apigee-lb-ip"
}

resource "google_apigee_envgroup" "apigee_envgroup" {
  name      = "eval-group"
  org_id    = google_apigee_organization.apigee_org.id
  hostnames = ["${google_compute_global_address.lb_external_ip.address}.nip.io"]
}

resource "google_apigee_envgroup_attachment" "env_to_envgroup" {
  envgroup_id = google_apigee_envgroup.apigee_envgroup.id
  environment = google_apigee_environment.apigee_env.name
}

resource "google_compute_region_network_endpoint_group" "apigee_psc_neg" {
  name                  = "apigee-psc-neg"
  region                = var.region
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = google_apigee_instance.apigee_instance.service_attachment
  network               = google_compute_network.apigee_vpc.id
  subnetwork            = google_compute_subnetwork.apigee_subnetwork.id
}

resource "google_compute_backend_service" "apigee_backend" {
  name                  = "apigee-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  
  backend {
    group = google_compute_region_network_endpoint_group.apigee_psc_neg.id
  }
}

resource "google_compute_url_map" "apigee_url_map" {
  name            = "apigee-lb-url-map"
  default_service = google_compute_backend_service.apigee_backend.id
}

resource "google_compute_managed_ssl_certificate" "apigee_cert" {
  name = "apigee-managed-cert"

  managed {
    domains = ["${google_compute_global_address.lb_external_ip.address}.nip.io"]
  }
}

resource "google_compute_target_https_proxy" "apigee_https_proxy" {
  name             = "apigee-https-proxy"
  url_map          = google_compute_url_map.apigee_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.apigee_cert.id]
}

resource "google_compute_global_forwarding_rule" "apigee_forwarding_rule" {
  name                  = "apigee-https-rule"
  target                = google_compute_target_https_proxy.apigee_https_proxy.id
  port_range            = "443"
  ip_address            = google_compute_global_address.lb_external_ip.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# ------------------------------------------------------------------------------
# 4. APIGEE API HUB PROVISIONING
# ------------------------------------------------------------------------------

# Register the project as an API Hub Host Project
resource "google_apihub_host_project_registration" "apihub_host_project" {
  project                      = var.project_id
  location                     = var.region
  host_project_registration_id = var.project_id
  gcp_project                  = "projects/${var.project_id}"
  
  depends_on = [google_apigee_organization.apigee_org]
}

# Create the API Hub Service Identity
resource "google_project_service_identity" "apihub_identity" {
  provider = google-beta
  project  = var.project_id
  service  = "apihub.googleapis.com"
}

# Bind required IAM roles for the API Hub Service Identity
resource "google_project_iam_member" "apihub_admin_binding" {
  project = var.project_id
  role    = "roles/apihub.admin"
  member  = "serviceAccount:${google_project_service_identity.apihub_identity.email}"
}

resource "google_project_iam_member" "apihub_runtime_binding" {
  project = var.project_id
  role    = "roles/apihub.runtimeProjectServiceAgent"
  member  = "serviceAccount:${google_project_service_identity.apihub_identity.email}"
}

# Provision the API Hub Instance
resource "google_apihub_api_hub_instance" "apihub_instance" {
  project             = var.project_id
  location            = var.region

  config {
    # We disable Vertex AI semantic search here to keep the eval setup simple 
    # and avoid requiring additional AI APIs to be enabled in a blank project.
    disable_search = true 
  }

  depends_on = [
    google_apihub_host_project_registration.apihub_host_project,
    google_project_iam_member.apihub_admin_binding,
    google_project_iam_member.apihub_runtime_binding
  ]
}

# ------------------------------------------------------------------------------
# 5. OUTPUTS
# ------------------------------------------------------------------------------

output "apigee_host" {
  description = "The dynamic hostname to access Apigee"
  value       = "${google_compute_global_address.lb_external_ip.address}.nip.io"
}

output "load_balancer_ip" {
  description = "The external IP of the load balancer"
  value       = google_compute_global_address.lb_external_ip.address
}
