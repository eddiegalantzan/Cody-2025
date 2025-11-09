output "server_ip" {
  description = "Application server IP address"
  value       = digitalocean_droplet.app_server.ipv4_address
}

output "database_host" {
  description = "Database host (same as server IP - localhost for app, IP for remote access)"
  value       = digitalocean_droplet.app_server.ipv4_address
}

output "database_port" {
  description = "Database port"
  value       = 5432
}

output "database_name" {
  description = "Database name"
  value       = var.database_name
}

output "database_user" {
  description = "Database user"
  value       = var.database_user
}

output "database_password" {
  description = "Database password"
  value       = random_password.db_password.result
  sensitive   = true
}

output "database_url" {
  description = "Full database connection URL (for remote access)"
  value       = "postgresql://${var.database_user}:${random_password.db_password.result}@${digitalocean_droplet.app_server.ipv4_address}:5432/${var.database_name}"
  sensitive   = true
}

output "database_url_local" {
  description = "Database connection URL for localhost (use this in application)"
  value       = "postgresql://${var.database_user}:${random_password.db_password.result}@localhost:5432/${var.database_name}"
  sensitive   = true
}

output "droplet_id" {
  description = "Droplet ID"
  value       = digitalocean_droplet.app_server.id
}

output "droplet_name" {
  description = "Droplet name"
  value       = digitalocean_droplet.app_server.name
}

output "app_url" {
  description = "Application URL (HTTP)"
  value       = "http://${digitalocean_droplet.app_server.ipv4_address}:${var.app_port}"
}

output "app_port" {
  description = "Application server port"
  value       = var.app_port
}

output "node_version" {
  description = "Installed Node.js version"
  value       = var.node_version
}

