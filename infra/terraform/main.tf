provider "digitalocean" {
  token = var.do_token
}

# DigitalOcean Project (creates project for organizing resources)
# Project is environment-specific (staging only for now)
resource "digitalocean_project" "main" {
  name        = var.project_name
  description = "Cody-2025 ${var.environment} infrastructure"
  purpose     = "Web Application"
  environment = "Staging" # Staging environment only (production will be added when client is secured)

  # Resources will be added after they're created (see project_resources below)
  resources = []
}

# Generate random password for database
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# SSH Key (optional - for direct server access)
# Uncomment and configure if you need SSH access to the droplet
# data "digitalocean_ssh_key" "main" {
#   name = "your-ssh-key-name"
# }

# Droplet for full-stack application (PostgreSQL + Backend + Frontend)
resource "digitalocean_droplet" "app_server" {
  image  = "ubuntu-22-04-x64"
  name   = "cody2025-app-${var.environment}"
  region = var.region
  size   = var.droplet_size
  # ssh_keys = [data.digitalocean_ssh_key.main.id] # Uncomment if using SSH key

  tags = ["postgres", "database", "backend", "frontend", var.environment]

  user_data = templatefile("${path.module}/user_data.sh", {
    postgres_version = var.postgres_version
    database_name    = var.database_name
    database_user    = var.database_user
    db_password      = random_password.db_password.result
    node_version     = var.node_version
    app_port         = var.app_port
  })
}

# Firewall rules for application server
resource "digitalocean_firewall" "app_server" {
  name = "cody2025-app-${var.environment}"

  droplet_ids = [digitalocean_droplet.app_server.id]

  # HTTP and HTTPS
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Application port (if not using reverse proxy)
  inbound_rule {
    protocol         = "tcp"
    port_range       = tostring(var.app_port)
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # PostgreSQL (restrict to specific IPs if provided, otherwise allow from anywhere for staging)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "5432"
    source_addresses = length(var.allowed_ips) > 0 ? var.allowed_ips : ["0.0.0.0/0", "::/0"]
  }

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"] # SSH from anywhere (restrict in production)
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Add resources to the project after they're created
# Note: DigitalOcean projects use URNs (Uniform Resource Names) for resources
resource "digitalocean_project_resources" "main" {
  project = digitalocean_project.main.id
  resources = [
    digitalocean_droplet.app_server.urn
  ]
}
