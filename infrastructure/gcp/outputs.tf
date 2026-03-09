output "instance_ip" {
  description = "External IP address of the DefectDojo VM"
  value       = google_compute_address.defectdojo_ip.address
}

output "instance_name" {
  description = "Name of the GCP VM instance"
  value       = google_compute_instance.defectdojo.name
}

output "instance_zone" {
  description = "Zone of the GCP VM instance"
  value       = google_compute_instance.defectdojo.zone
}

output "defectdojo_url" {
  description = "URL to access DefectDojo"
  value       = "http://${google_compute_address.defectdojo_ip.address}:8080"
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ubuntu@${google_compute_address.defectdojo_ip.address}"
}