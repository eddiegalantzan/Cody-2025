# Cody-2025

HS Code Classifier Application with 99.99% accuracy. Rules, guidelines, and plans for self-managed PostgreSQL database with Terraform.

**Company:** Israeli company serving worldwide customers  
**Business Model:** B2B (Business-to-Business)

## Application Goal

HS Code Classifier with 99.99% accuracy:
- Classify product descriptions to HS codes based on **known customs books** (country-specific)
- **Israel:** 3 customs books (verify and implement all 3)
- **Other countries:** Different customs books and rules
- Interactive questions when HS code unknown
- Reject abstract descriptions (e.g., "gift")
- Company item code list upload and lookup
- Pricing: X per standard transaction, X/D per list lookup transaction, M×X for interactive/abstract description

**Service Access Methods (Unified Workflow):**
All methods follow the same pattern:
1. User provides product description
2. User specifies customs book (optional, defaults if not provided)
3. System processes classification
4. User receives HS code result(s) for item(s)

**Interactive Workflow Continuation (API Methods):**
- If classification requires questions, system returns session ID
- User continues by sending session ID + answers via API
- Process continues until complete or session expires

**Access Methods:**
- **Frontend App:** Web interface with interactive Q&A, real-time results
- **Email to Email:** Send email with description and customs book, receive result email with HS code(s)
- **API Webhook (Async):** POST request, receive job ID (or session ID if interactive), get result via webhook callback. Continue workflow with session ID + answers
- **API Synchronous:** POST request, wait for immediate response with HS code(s) or questions. Continue workflow with session ID + answers

## Quick Start
1. Read [2.0_PROJECT_RULES.md](./documents/2.0_PROJECT_RULES.md)
2. Review [5.0_PLAN.md](./documents/5.0_PLAN.md)
3. Start [6.0_STEP_1_TERRAFORM_POSTGRES.md](./documents/6.0_STEP_1_TERRAFORM_POSTGRES.md)

## Documentation

1. [1.0_PRINCIPLES.md](./documents/1.0_PRINCIPLES.md) - Core principles
2. [2.0_PROJECT_RULES.md](./documents/2.0_PROJECT_RULES.md) - Complete project rules
3. [3.0_USER_RULES.md](./documents/3.0_USER_RULES.md) - Quick reference
4. [4.0_WRAPPERS_GUIDE.md](./documents/4.0_WRAPPERS_GUIDE.md) - Wrapper implementation
5. [5.0_PLAN.md](./documents/5.0_PLAN.md) - Overall project plan
6. [6.0_STEP_1_TERRAFORM_POSTGRES.md](./documents/6.0_STEP_1_TERRAFORM_POSTGRES.md) - Terraform setup
7. [6.1_DIGITALOCEAN_SETUP.md](./documents/6.1_DIGITALOCEAN_SETUP.md) - DigitalOcean account setup
8. [7.0_SECRETS_MANAGEMENT.md](./documents/7.0_SECRETS_MANAGEMENT.md) - Secrets configuration
9. [8.0_SECURITY.md](./documents/8.0_SECURITY.md) - Security practices
10. [9.0_INTEGRATIONS.md](./documents/9.0_INTEGRATIONS.md) - Third-party integrations (Clerk, Payoneer, Mailgun, WhatsApp)

## Resources

### Infrastructure
- Terraform: https://www.terraform.io/docs
- PostgreSQL: https://www.postgresql.org/docs/
- Cloud Providers: DigitalOcean, Vultr, Hetzner, Linode

### Third-Party Services
- **Clerk.com**: https://clerk.com/docs - User authentication and management
- **Payoneer**: https://www.payoneer.com/partners/integrated-payments-api/ - Payment processing API
- **Mailgun**: https://documentation.mailgun.com/ - Email delivery and receiving
- **WhatsApp Business API**: https://developers.facebook.com/docs/whatsapp - Official Meta WhatsApp messaging

### Development
- TypeScript: https://www.typescriptlang.org/docs/
- tRPC: https://trpc.io/docs
- React: https://react.dev/
