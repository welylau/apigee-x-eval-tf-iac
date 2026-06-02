variable "project_id" {
  description = "The GCP Project ID where resources will be provisioned."
  type        = string
}

variable "region" {
  description = "The GCP region for Apigee, Subnets, and API Hub."
  type        = string
  default     = "us-central1"
}
