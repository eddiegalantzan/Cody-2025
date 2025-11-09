# Terraform Infrastructure Setup

This directory contains Terraform configuration for provisioning a **full-stack application server** on DigitalOcean with:
- **PostgreSQL database** (self-managed)
- **Backend application** (Node.js/TypeScript)
- **Frontend application** (React)

All services run on a single droplet for cost-effective staging deployment.

## Architecture

**Single Server Setup (Staging):**
- One DigitalOcean droplet hosts everything
- PostgreSQL database (port 5432)
- Node.js backend application (port 3000)
- Frontend served by backend or separate process
- All services accessible via HTTP/HTTPS

**Benefits:**
- Cost-effective: ~$6/month to start (upgrade if needed)
- Simple deployment and management
- Good for staging/testing environments
- Easy to upgrade droplet size or scale to separate servers later if needed

## Prerequisites

1. **Terraform** ≥ 1.7 installed
   ```bash
   brew install terraform  # macOS
   # or download from https://www.terraform.io/downloads
   ```

2. **DigitalOcean Account**
   - Sign up at https://www.digitalocean.com
   - Create API token at https://cloud.digitalocean.com/account/api/tokens
   - Token needs "Write" scope
   - **📖 Detailed Setup Guide:** See [6.1_DIGITALOCEAN_SETUP.md](../../documents/6.1_DIGITALOCEAN_SETUP.md) for step-by-step instructions

## Quick Start

1. **Copy the example variables file:**
   ```bash
   cd infra/terraform
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars` with your values:**
   - Add your DigitalOcean API token
   - Adjust region, size, and other settings as needed
   - **Recommended:** Use `s-1vcpu-2gb` or larger for full-stack

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Review the plan:**
   ```bash
   terraform plan
   ```

5. **Apply the configuration:**
   ```bash
   terraform apply
   ```

6. **Get connection details:**
   ```bash
   terraform output server_ip
   terraform output database_url_local
   terraform output app_url
   ```

## What Gets Installed

The server automatically installs and configures:

- **PostgreSQL 16** - Database server
- **Node.js 22** - Runtime for backend/frontend
- **Yarn** - Package manager
- **PM2** - Process manager for Node.js apps
- **UFW Firewall** - Configured for HTTP, HTTPS, SSH, PostgreSQL, and app port

## Configuration

### Environment
- `local` - For local development (not typically used with cloud)
- `cody2025staging` - For staging environment

**Note:** Production environment will be added when client is secured.

### Regions
Recommended EU regions for Israeli company serving worldwide:
- `fra1` - Frankfurt (default)
- `ams3` - Amsterdam
- `lon1` - London

### Droplet Sizes
- `s-1vcpu-1gb` - $6/month (default, start here)
- `s-1vcpu-2gb` - $12/month (upgrade if you need more memory/CPU)
- `s-2vcpu-4gb` - $24/month (if you need more resources)
- See https://www.digitalocean.com/pricing for full list

**Strategy:** Start with the smallest size (`s-1vcpu-1gb`) and upgrade if you experience:
- Out-of-memory errors
- Slow performance
- Database connection issues
- Application crashes

**To upgrade:** Change `droplet_size` in `terraform.tfvars` and run `terraform apply` (Terraform will resize the droplet).

### Ports
- **80** - HTTP (for reverse proxy/nginx if configured)
- **443** - HTTPS (for reverse proxy/nginx if configured)
- **3000** - Application server (default, configurable)
- **5432** - PostgreSQL database
- **22** - SSH

## Security

- Database password is auto-generated and stored in Terraform state
- Firewall rules configured for HTTP, HTTPS, SSH, and PostgreSQL
- PostgreSQL accessible from anywhere in staging (restrict with `allowed_ips` for production)
- **Never commit `terraform.tfvars`** (already in `.gitignore`)

## Outputs

After `terraform apply`, you'll get:
- `server_ip` - IP address of the application server
- `database_host` - Database host (same as server IP)
- `database_port` - Port (5432)
- `database_name` - Database name
- `database_user` - Database user
- `database_password` - Auto-generated password (sensitive)
- `database_url` - Full connection URL for remote access (sensitive)
- `database_url_local` - Connection URL for localhost (use in application) (sensitive)
- `app_url` - Application URL (HTTP)
- `app_port` - Application server port
- `node_version` - Installed Node.js version

## Application Deployment

After provisioning, you'll need to:

1. **SSH into the server:**
   ```bash
   ssh root@<server_ip>
   ```

2. **Deploy your application code** to `/opt/cody2025`

3. **Configure environment variables** (database connection, secrets, etc.)

4. **Start the application** using PM2 or systemd

5. **Set up reverse proxy** (nginx) if you want to use port 80/443 instead of 3000

## Database Connection

**From the application (on the same server):**
Use `localhost` or `127.0.0.1`:
```
postgresql://app_user:password@localhost:5432/cody2025
```

**From your local machine (remote access):**
Use the server IP:
```
postgresql://app_user:password@<server_ip>:5432/cody2025
```

Get the connection string:
```bash
terraform output database_url_local  # For app on server
terraform output database_url          # For remote access
```

## Troubleshooting

- **Provider not found:** Run `terraform init`
- **Auth failed:** Check your DigitalOcean API token
- **Connection fails:** Wait a few minutes for server initialization, check firewall rules
- **State locked:** `terraform force-unlock <LOCK_ID>`
- **Application not accessible:** Check firewall rules, verify app is running on correct port
- **Out of memory / Performance issues:** Upgrade droplet size:
  1. Edit `terraform.tfvars`: change `droplet_size = "s-1vcpu-2gb"`
  2. Run `terraform plan` to see the resize operation
  3. Run `terraform apply` to upgrade (this will resize the droplet)

## Cost

- **Droplet:** $6-24/month depending on size (start with $6/month, upgrade if needed)
- **Storage:** Included in droplet price
- **Total:** ~$6/month initially, upgrade to $12-24/month if performance requires it

## Next Steps

After provisioning:
1. Test database connection
2. Deploy application code to `/opt/cody2025`
3. Configure environment variables and secrets
4. Start application with PM2 or systemd
5. Set up secrets management (see [7.0_SECRETS_MANAGEMENT.md](../../documents/7.0_SECRETS_MANAGEMENT.md))
6. Create database schema (see [5.0_PLAN.md](../../documents/5.0_PLAN.md) Phase 2)

## Related Documentation

- [6.0_STEP_1_TERRAFORM_POSTGRES.md](../../documents/6.0_STEP_1_TERRAFORM_POSTGRES.md) - Detailed setup guide
- [7.0_SECRETS_MANAGEMENT.md](../../documents/7.0_SECRETS_MANAGEMENT.md) - Secrets configuration
- [8.0_SECURITY.md](../../documents/8.0_SECURITY.md) - Security practices
