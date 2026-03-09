terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    # Values passed via -backend-config in the pipeline:
    # bucket = "<project-id>-tfstate"
    # prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ── Network ────────────────────────────────────────────────────────────────────

resource "google_compute_network" "defectdojo_vpc" {
  name                    = "defectdojo-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "defectdojo_subnet" {
  name          = "defectdojo-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.defectdojo_vpc.id
}

# ── Firewall ───────────────────────────────────────────────────────────────────

resource "google_compute_firewall" "allow_ssh" {
  name    = "defectdojo-allow-ssh"
  network = google_compute_network.defectdojo_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["defectdojo"]
}

resource "google_compute_firewall" "allow_http" {
  name    = "defectdojo-allow-http"
  network = google_compute_network.defectdojo_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8080", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["defectdojo"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "defectdojo-allow-internal"
  network = google_compute_network.defectdojo_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.1.0/24"]
}

# ── Static IP ──────────────────────────────────────────────────────────────────

resource "google_compute_address" "defectdojo_ip" {
  name   = "defectdojo-static-ip"
  region = var.region
}

# ── VM Instance ────────────────────────────────────────────────────────────────

resource "google_compute_instance" "defectdojo" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["defectdojo"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50   # GB — DefectDojo needs ~20GB minimum
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.defectdojo_subnet.id

    access_config {
      nat_ip = google_compute_address.defectdojo_ip.address
    }
  }

  # Startup script — just prepares the VM, Ansible does the real work
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update -qq
    apt-get install -y curl wget git
    echo "VM ready" > /tmp/startup-done
  EOF

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  # Allow stopping for updates
  allow_stopping_for_update = true

  labels = {
    environment = "production"
    app         = "defectdojo"
    managed-by  = "terraform"
  }
}