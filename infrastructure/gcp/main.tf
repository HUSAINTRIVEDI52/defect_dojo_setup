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
  default     = "security-suite-main"
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

# Network VPC
resource "google_compute_network" "vpc" {
  name                    = "security-suite-vpc"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "security-suite-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Firewall Rules
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"] # In production, restrict this
  target_tags   = ["ssh-enabled"]
}

resource "google_compute_firewall" "allow_defectdojo" {
  name    = "allow-defectdojo"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["dojo-enabled"]
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
      size  = 50
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
}

output "instance_ip" {
  value = google_compute_instance.main.network_interface[0].access_config[0].nat_ip
}

output "instance_name" {
  value = google_compute_instance.main.name
} 