terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "gcs" {
    # Bucket name will be passed via -backend-config
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

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
  description = "Name of the compute instance"
  type        = string
  default     = "defectdojo-main"
}

variable "machine_type" {
  description = "GCP Machine Type"
  type        = string
  default     = "e2-custom-4-8192"
}

variable "ssh_pub_key" {
  description = "Public SSH key for deployment"
  type        = string
}

variable "defectdojo_port" {
  description = "Port for DefectDojo web interface"
  type        = string
  default     = "8080"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

# Network VPC
resource "google_compute_network" "vpc" {
  name                    = "defectdojo-vpc"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "defectdojo-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Firewall Rule: Allow SSH
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"] # SECURITY: Restrict this in production
  target_tags   = ["ssh-enabled"]
  
  description = "Allow SSH access for deployment and management"
}

# Firewall Rule: Allow DefectDojo
resource "google_compute_firewall" "allow_defectdojo" {
  name    = "allow-defectdojo"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = [var.defectdojo_port]
  }

  source_ranges = ["0.0.0.0/0"] # SECURITY: Restrict this in production
  target_tags   = ["dojo-enabled"]
  
  description = "Allow access to DefectDojo web interface"
}

# Firewall Rule: Allow ICMP (ping)
resource "google_compute_firewall" "allow_icmp" {
  name    = "allow-icmp"
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-enabled", "dojo-enabled"]
  
  description = "Allow ICMP for connectivity testing"
}

# Compute Instance
resource "google_compute_instance" "main" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["ssh-enabled", "dojo-enabled"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.subnet.name

    access_config {
      # Ephemeral public IP
    }
  }

  metadata = {
    enable-oslogin = "FALSE"
    ssh-keys       = "ubuntu:${var.ssh_pub_key}"
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  labels = {
    environment = "production"
    application = "defectdojo"
    managed-by  = "terraform"
  }
}

# Outputs
output "instance_ip" {
  value       = google_compute_instance.main.network_interface[0].access_config[0].nat_ip
  description = "Public IP address of the DefectDojo instance"
}

output "instance_name" {
  value       = google_compute_instance.main.name
  description = "Name of the compute instance"
}

output "instance_zone" {
  value       = google_compute_instance.main.zone
  description = "Zone of the compute instance"
}

output "defectdojo_url" {
  value       = "http://${google_compute_instance.main.network_interface[0].access_config[0].nat_ip}:${var.defectdojo_port}"
  description = "DefectDojo access URL"
}

output "ssh_command" {
  value       = "ssh ubuntu@${google_compute_instance.main.network_interface[0].access_config[0].nat_ip}"
  description = "SSH command to connect to the instance"
}