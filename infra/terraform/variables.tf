variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name (local, cody2025staging)"
  type        = string
  default     = "cody2025staging"
  validation {
    condition     = contains(["local", "cody2025staging"], var.environment)
    error_message = "Environment must be 'local' or 'cody2025staging'."
  }
}

variable "region" {
  description = "DigitalOcean region (e.g., fra1 for Frankfurt, ams3 for Amsterdam, lon1 for London)"
  type        = string
  default     = "fra1" # Frankfurt (EU) - good for Israeli company serving worldwide
}

variable "droplet_size" {
  description = "Droplet size slug (start with s-1vcpu-1gb, upgrade if needed)"
  type        = string
  default     = "s-1vcpu-1gb" # $6/month - start small, upgrade if performance issues
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = "cody2025"
}

variable "database_user" {
  description = "Database user name"
  type        = string
  default     = "app_user"
}

variable "allowed_ips" {
  description = "List of IP addresses allowed to access the database (CIDR notation)"
  type        = list(string)
  default     = []
}

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "storage_size_gb" {
  description = "Storage size in GB"
  type        = number
  default     = 25
}

variable "node_version" {
  description = "Node.js version"
  type        = string
  default     = "22"
}

variable "app_port" {
  description = "Application server port"
  type        = number
  default     = 3000
}

variable "project_name" {
  description = "DigitalOcean project name (environment-specific, e.g., 'Cody-2025-Staging')"
  type        = string
  default     = "Cody-2025-Staging" # Staging environment project
}

