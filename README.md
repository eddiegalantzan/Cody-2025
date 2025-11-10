# Cody-2025

HS Code Classifier Application with 99.99% accuracy. Rules, guidelines, and plans for self-managed PostgreSQL database with Terraform.

**Company:** Israeli company serving worldwide customers  
**Business Model:** B2B (Business-to-Business)

## Application Goal

HS Code Classifier with 99.99% accuracy:
- Classify product descriptions to HS codes based on **known customs books** (country-specific)
- **Israel:** 3 customs books (verify and implement all 3)
- **Other countries:** Different customs books and rules
- **Customs Book Rules Database:** Store classification rules in database for LLM context
- **LLM-Based Data Extraction:** Use LLM to extract structured data (HS codes, rules) from customs book PDFs and text
- **Automated Data Synchronization (Mehavizim):** Automated systems to populate and keep customs book data up-to-date
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

## User Roles

The application uses a B2B organization-based access model with role-based permissions. Users belong to organizations and have specific roles that determine their access level.

### Organization Roles

Roles are defined in the `organization_members` table with the following hierarchy (from highest to lowest privilege):

1. **Owner** (`owner`)
   - Full control over the organization
   - Can manage all organization settings
   - Can delete the organization
   - Can manage all members (invite, remove, change roles)
   - Can manage billing and payment accounts
   - Can access all organization data and classifications
   - Can manage API keys and webhooks

2. **Admin** (`admin`)
   - Can manage organization settings (except deletion)
   - Can manage members (invite, remove, change roles except owner)
   - Can access all organization data and classifications
   - Can manage API keys and webhooks
   - Cannot delete the organization or change owner role

3. **Member** (`member`)
   - Can create and view their own classifications
   - Can view organization-level data (shared classifications, item code lists)
   - Can upload and manage company item code lists
   - Cannot manage organization settings or members
   - Cannot access billing or payment information

4. **Viewer** (`viewer`)
   - Read-only access to organization data
   - Can view classifications (own and shared)
   - Can view organization-level data
   - Cannot create classifications or modify any data
   - Cannot access sensitive information (billing, API keys)

### Role Permissions

Each role can have additional fine-grained permissions stored in the `organization_member_permissions` JSONB field, allowing for custom permission sets beyond the base role capabilities.

### Data Isolation

All data (classifications, item code lists, transactions, etc.) is isolated at the organization level. Users can only access data belonging to their organization, and role permissions determine what actions they can perform on that data.

## Quick Start

### Prerequisites
- Node.js 20+ ([Download](https://nodejs.org/))
- Yarn ([Install Yarn](https://yarnpkg.com/getting-started/install))
- PostgreSQL 16+ (for database)
- Terraform ≥ 1.7 (for infrastructure)

### Installation

```bash
# Clone the repository (if applicable)
# cd CiCd

# Install dependencies
yarn install
```

### Getting Started
1. Read [2.0_PROJECT_RULES.md](./documents/2.0_PROJECT_RULES.md)
2. Review [5.0_PLAN.md](./documents/5.0_PLAN.md)
3. Start [6.0_STEP_1_TERRAFORM_POSTGRES.md](./documents/6.0_STEP_1_TERRAFORM_POSTGRES.md)

### Scripts

```bash
# Download WCO PDFs (browser-based, recommended)
yarn download-wco-pdfs:browser --headless

# Download WCO PDFs (HTTP-based)
yarn download-wco-pdfs

# Convert PDFs to Markdown (for LLM processing)
yarn pdf-to-markdown --tool marker

# See help
yarn download-wco-pdfs:browser:help
yarn download-wco-pdfs:help
yarn pdf-to-markdown:help
```

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
10. [9.0_INTEGRATIONS.md](./documents/9.0_INTEGRATIONS.md) - Third-party integrations (Clerk, Payoneer, Mailgun, WhatsApp, LLM Providers)
11. [10.0_HS_CODE_STRUCTURE.md](./documents/10.0_HS_CODE_STRUCTURE.md) - HS code structure and country-specific implementations
12. [11.0_CUSTOMS_DATA_DOWNLOAD.md](./documents/11.0_CUSTOMS_DATA_DOWNLOAD.md) - Guide for downloading customs data from official sources and automated synchronization mechanisms

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
- **LLM Providers**: 
  - **OpenAI**: https://platform.openai.com/docs - GPT-4, GPT-3.5 for HS code classification
  - **Anthropic**: https://docs.anthropic.com - Claude 3 for HS code classification
  - **Google Gemini**: https://ai.google.dev/docs - Gemini Pro/Ultra for HS code classification
  - **xAI (Grok)**: https://docs.x.ai - Grok-1, Grok-2 for HS code classification

### Development
- TypeScript: https://www.typescriptlang.org/docs/
- tRPC: https://trpc.io/docs
- React: https://react.dev/
