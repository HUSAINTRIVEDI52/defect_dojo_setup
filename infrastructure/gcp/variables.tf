variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "instance_name" {
  description = "Name of the GCP VM instance"
  type        = string
  default     = "defectdojo-vm"
}

variable "machine_type" {
  description = "GCP machine type — e2-standard-4 is minimum recommended for DefectDojo"
  type        = string
  default     = "e2-standard-2"   # 4 vCPU, 16GB RAM
}

variable "service_account_email" {
  description = "Service account email for the VM (leave empty to use default compute SA)"
  type        = string
  default     = ""
}