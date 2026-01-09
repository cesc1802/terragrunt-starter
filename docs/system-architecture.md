# System Architecture

## High-Level Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Cloud Infrastructure                  │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              PRODUCTION (prod)                        │   │
│  │  • Deletion Protection: Enabled                       │   │
│  │  • Multi-AZ: Enabled                                 │   │
│  │  • Instance Size: Large (r6g.large)                  │   │
│  │  • Regions: us-east-1 (primary), eu-west-1 (DR)     │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │          USER ACCEPTANCE TESTING (uat)               │   │
│  │  • Deletion Protection: Enabled                       │   │
│  │  • Multi-AZ: Disabled (single AZ for cost)          │   │
│  │  • Instance Size: Medium (t3.medium)                 │   │
│  │  • Region: us-east-1                                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │            STAGING & DEVELOPMENT                      │   │
│  │  • Deletion Protection: Disabled                      │   │
│  │  • Multi-AZ: Disabled                                │   │
│  │  • Instance Size: Small (t3.small / t3.micro)       │   │
│  │  • Region: us-east-1                                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Configuration Inheritance Hierarchy

```
                            root.hcl
                      (Root Configuration)
                              │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
   Backend Config        Provider Config         Global Tags
  (S3 + DynamoDB)   (AWS Provider Settings)   (Applied to all)
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                │
                                ▼
                    environments/{env}/env.hcl
                   (Environment Configuration)
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
          Environment      Instance Sizing    Deletion Policy
            (dev/stg/         (micro/small/    (true/false)
            uat/prod)         medium/large)
                │               │               │
                └───────────────┼───────────────┘
                                │
                                ▼
                 environments/{env}/{region}/region.hcl
                     (Region Configuration)
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
            AWS Region      Availability      Region-Specific
            (us-east-1/    Zones (us-east-1a/   Settings
             eu-west-1)    1b/1c, etc.)        (AMIs, etc.)
                │               │               │
                └───────────────┼───────────────┘
                                │
                                ▼
                   _envcommon/{category}/{module}.hcl
                  (Module Common Configuration)
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
          Module Source    Common Inputs      Default Settings
          (TF Registry)   (applied to all)    (overridable)
                │               │               │
                └───────────────┼───────────────┘
                                │
                                ▼
        environments/{env}/{region}/{category}/{module}/terragrunt.hcl
                    (Resource Deployment)
                                │
                ┌───────────────┼───────────────┐
                │               │               │
                ▼               ▼               ▼
           Include Chain    Environment      Dependencies
           (inheritance)    Overrides       (other modules)
                │               │               │
                └───────────────┼───────────────┘
                                │
                                ▼
                        ✓ Final Deployment
```

## Module Architecture

### Layer 1: Networking (VPC)

**Purpose:** Foundation for all infrastructure
**Dependencies:** None
**Outputs Used By:** RDS, ECS Cluster, other services

#### Configuration (Phase 05)
- **Module Source:** `terraform-aws-modules/vpc/aws v5.17.0`
- **Public Subnets:** Internet-facing, CIDRs via cidrsubnet() (+1,+2,+3 offsets)
- **Private Subnets:** Protected, CIDRs via cidrsubnet() (+11,+12,+13 offsets)
- **Database Subnets:** RDS-ready, CIDRs via cidrsubnet() (+21,+22,+23 offsets)
- **DNS:** Hostnames and support enabled
- **Internet Gateway:** Always created
- **NAT Gateways:** single_nat_gateway mode (one NAT per env if enabled)
- **Database Subnet Group:** Auto-created
- **Default Security Group:** Locked down (no ingress/egress)

#### Environment-Specific Settings (Phase 05)

| Setting | Dev | Staging | UAT | Prod |
|---|---|---|---|---|
| VPC CIDR | 10.10.0.0/16 | 10.20.0.0/16 | 10.30.0.0/16 | 10.40.0.0/16, 10.50.0.0/16 |
| AZs | 3 | 3 | 3 | 3 |
| Public Subnets | 3×/24 (+1,2,3) | 3×/24 | 3×/24 | 3×/24 |
| Private Subnets | 3×/24 (+11,12,13) | 3×/24 | 3×/24 | 3×/24 |
| Database Subnets | 3×/24 (+21,22,23) | 3×/24 | 3×/24 | 3×/24 |
| NAT Gateway | Disabled | Enabled | Enabled | Enabled (per-AZ) |
| Flow Logs | Disabled | Disabled | Disabled | Enabled |
| IGW | Yes | Yes | Yes | Yes |
| Default SG | Locked | Locked | Locked | Locked |

#### Deployment Order (Phase 05)
```
_envcommon/networking/vpc.hcl (common config + cidrsubnet() calculations)
  ↓
environments/{env}/us-east-1/01-infra/network/vpc/terragrunt.hcl (env-specific overrides)
  └─ Creates VPC with calculated subnets, route tables, DNS, optional NAT/Flow Logs
```

**Phase 05 Status:** Dev VPC deployed (10.10.0.0/16, NAT/Flow Logs disabled)

### Layer 2: Data Stores (RDS)

**Purpose:** Relational database backend
**Dependencies:** VPC (security groups, subnets)
**Outputs Used By:** ECS clusters, application services

#### Configuration
- **Module Source:** terraform-aws-modules/rds/aws
- **Engine:** PostgreSQL/MySQL (configurable)
- **Instance Class:** t3.micro (dev) → r6g.large (prod)
- **Storage:** 20GB (dev) → 100GB+ (prod)
- **Backup Retention:** 7 days (dev) → 30 days (prod)

#### Environment-Specific Settings

| Setting | Dev | Staging | UAT | Prod |
|---|---|---|---|---|
| Instance Class | t3.micro | t3.small | t3.small | r6g.large |
| Storage | 20GB | 30GB | 50GB | 100GB |
| Multi-AZ | No | No | No | Yes |
| Backup Retention | 7 days | 14 days | 14 days | 30 days |
| Enhanced Monitoring | No | No | No | Yes |
| Deletion Protection | No | No | Yes | Yes |

#### Deployment Order
```
environments/{env}/us-east-1/01-infra/network/vpc/
  ↓ (requires VPC security groups, subnets)
environments/{env}/us-east-1/02-data/rds/
  └─ Creates RDS instance with security group rules
```

### Layer 3: Services (ECS Cluster)

**Purpose:** Container orchestration for applications
**Dependencies:** VPC, IAM roles
**Outputs Used By:** Load balancers, other services

#### Configuration
- **Module Source:** terraform-aws-modules/ecs/aws
- **Launch Type:** EC2 (requires auto-scaling group)
- **Logging:** CloudWatch Logs (all envs), Container Insights (prod only)
- **IAM Roles:** ECS task role, instance role

#### Environment-Specific Settings

| Setting | Dev | Staging | UAT | Prod |
|---|---|---|---|---|
| Instance Count | 1-2 | 2 | 2-3 | 3+ |
| Instance Type | t3.micro | t3.small | t3.medium | m6g.large |
| Container Insights | Disabled | Disabled | Disabled | Enabled |
| Logging | CloudWatch | CloudWatch | CloudWatch | CloudWatch + Splunk |
| Placement Strategy | Any | Any | Any | Spread (AZ diversity) |

#### Deployment Order
```
environments/{env}/us-east-1/01-infra/network/vpc/
  ↓ (requires VPC subnets, security groups)
environments/{env}/us-east-1/03-services/ecs-cluster/
  └─ Creates ECS cluster, auto-scaling group, instances
```

## Multi-Region Architecture (Production)

```
┌────────────────────────────────────────────────────────────┐
│                  AWS Global Infrastructure                  │
├────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────┐  ┌─────────────────────────┐  │
│  │    US-EAST-1 (Primary)  │  │  EU-WEST-1 (Disaster   │  │
│  │                         │  │  Recovery)              │  │
│  │  VPC: 10.30.0.0/16      │  │  VPC: 10.40.0.0/16     │  │
│  │  • AZs: a, b, c         │  │  • AZs: a, b, c        │  │
│  │  • RDS: Multi-AZ        │  │  • RDS: Multi-AZ       │  │
│  │  • ECS: Multi-AZ        │  │  • ECS: Multi-AZ       │  │
│  │  • NAT: 3 per-AZ        │  │  • NAT: 3 per-AZ       │  │
│  │                         │  │                        │  │
│  │  Active Read/Write      │  │  Standby (RTO 30 min)  │  │
│  └─────────────────────────┘  └─────────────────────────┘  │
│           │                              │                  │
│           │ VPC Peering (non-overlapping CIDR)              │
│           └──────────────────────────────┘                  │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Shared Services (Global)                           │   │
│  │  • Route53 (DNS + health checks)                    │   │
│  │  • CloudFront (CDN)                                 │   │
│  │  • S3 (cross-region replication)                    │   │
│  │  • Secrets Manager (cross-region)                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└────────────────────────────────────────────────────────────┘
```

### Failover Strategy

**Recovery Time Objective (RTO):** 30 minutes
**Recovery Point Objective (RPO):** 5 minutes

#### Failover Procedure

1. **Detect Failure** (CloudWatch health checks, Route53)
   - Primary region detects primary RDS failure
   - Route53 health check failure triggers failover
   - Manual confirmation required for critical workloads

2. **Promote Read Replica** (if available)
   - EU-West-1 RDS read replica promoted to primary
   - DNS updated to point to secondary region
   - Application traffic redirects to secondary

3. **Verify Services**
   - ECS cluster in EU-West-1 pulls latest task definitions
   - Application services restart with secondary RDS
   - Health checks confirm successful failover

4. **Restore Primary** (when available)
   - Restore primary RDS from automated backups
   - Sync data with promoted replica
   - Re-establish replication
   - Switch traffic back after validation

## State Management Architecture

```
┌──────────────────────────────────┐
│   Terraform State (Remote)       │
├──────────────────────────────────┤
│                                  │
│  S3 Bucket: terraform-state      │
│  • Versioning: Enabled           │
│  • Encryption: SSE-S3            │
│  • Lifecycle: 30-day retention   │
│  • Logging: CloudTrail audit     │
│                                  │
│  DynamoDB Table: terraform-locks │
│  • PK: LockID (state path)       │
│  • TTL: Prevents stale locks     │
│  • Encryption: At rest           │
│                                  │
└──────────────────────────────────┘
        │
        └─ Accessed via terragrunt.hcl backend
             └─ Locked during apply operations
```

## Tagging Strategy

All resources receive default tags applied at provider level:

```hcl
default_tags {
  tags = {
    Project             = "terragrunt-starter"
    Environment         = local.environment    # dev/staging/uat/prod
    ManagedBy           = "Terraform"
    ManagedByModule     = var.module_name
    CostAllocation      = local.cost_allocation_tag
    CreatedDate         = timestamp()
    LastModifiedDate    = timestamp()
  }
}
```

### Custom Tags (Resource-Level)

```hcl
tags = {
  Name                = "uat-web-server-01"
  Service             = "web"
  Criticality         = "high"          # high/medium/low
  BackupRequired      = "true"
  DisasterRecovery    = "enabled"
}
```

## Security Architecture

### Network Security

```
┌─────────────────────────────────┐
│      AWS Region (us-east-1)     │
├─────────────────────────────────┤
│                                 │
│  VPC: 10.30.0.0/16              │
│  └─ Internet Gateway (IGW)      │
│     └─ Public Subnets           │
│        └─ NAT Gateway (EIP)     │
│        └─ Load Balancer (ALB)   │
│           └─ Security Group: 80,443
│                                 │
│     └─ Private Subnets          │
│        └─ ECS Instances         │
│        └─ RDS Database          │
│           └─ Security Group: app-only
│                                 │
│  Flow Logs → CloudWatch Logs    │
│  (prod only)                    │
│                                 │
└─────────────────────────────────┘
```

### IAM Architecture

```
Root Account
├─ Service Roles
│  ├─ ECS Task Execution Role
│  │  └─ Permissions: ECR pull, CloudWatch logs
│  ├─ ECS Task Role
│  │  └─ Permissions: S3, DynamoDB, Secrets Manager
│  └─ RDS Enhanced Monitoring Role
│     └─ Permissions: CloudWatch logs
│
├─ User Roles (assumed by developers)
│  ├─ Developer (dev/staging only)
│  ├─ DevOps (all environments, read-only prod)
│  └─ Admin (prod, requires MFA)
│
└─ Service Accounts
   └─ CI/CD (GitHub Actions)
      └─ Permissions: plan/apply to dev/staging only
```

### Data Protection

| Layer | Dev | Staging | UAT | Prod |
|---|---|---|---|---|
| **Encryption at Rest** | No | No | Yes | Yes |
| **Encryption in Transit** | HTTP/S | HTTP/S | HTTPS only | HTTPS only |
| **DB Encryption** | No | No | Yes | Yes |
| **Backup Encryption** | No | No | Yes | Yes |
| **Deletion Protection** | No | No | Yes | Yes |

## Observability Architecture

### Monitoring Stack

```
┌────────────────────────────────┐
│   CloudWatch Dashboards        │
├────────────────────────────────┤
│                                │
│  Metrics:                      │
│  • CPU, Memory, Disk (EC2)     │
│  • RDS: connections, queries   │
│  • ECS: task count, failures   │
│  • Load Balancer: requests     │
│  • Custom: application metrics │
│                                │
│  Logs:                         │
│  • /aws/ec2/system             │
│  • /aws/ecs/cluster            │
│  • /aws/rds/instance           │
│  • /app/application            │
│                                │
│  Alarms:                       │
│  • High CPU (>80%)             │
│  • Low disk space (<10%)       │
│  • RDS failover                │
│  • ECS task failures           │
│                                │
└────────────────────────────────┘
```

### Logging Strategy

| Log Type | Destination | Retention | Purpose |
|---|---|---|---|
| **VPC Flow Logs** | CloudWatch | 30 days (prod) | Network traffic analysis |
| **CloudTrail** | S3 + CloudWatch | 1 year | Audit trail, compliance |
| **Application Logs** | CloudWatch | 7 days (dev) → 30 days (prod) | Debugging, monitoring |
| **Load Balancer Logs** | S3 | 30 days | Request tracking, security |
| **RDS Logs** | CloudWatch | 7 days | Database activity, errors |

## Disaster Recovery Architecture

### Backup Strategy

```
┌─────────────────────────────────┐
│   Backup & Recovery             │
├─────────────────────────────────┤
│                                 │
│  RDS Automated Backups:         │
│  • Dev: 7-day retention         │
│  • Staging: 14-day retention    │
│  • UAT: 14-day retention        │
│  • Prod: 30-day retention       │
│                                 │
│  EBS Snapshots:                 │
│  • Hourly (prod)                │
│  • Daily (uat)                  │
│  • Weekly (dev/staging)         │
│                                 │
│  S3 Cross-Region Replication:   │
│  • Terraform state              │
│  • Application data (prod only) │
│  • Logs and backups             │
│                                 │
│  Point-in-Time Recovery:        │
│  • RDS: Within 35 days          │
│  • EBS: Latest snapshot         │
│                                 │
└─────────────────────────────────┘
```

### RTO/RPO Targets

| Component | RTO | RPO | Method |
|---|---|---|---|
| **RDS** | 30 min | 5 min | Auto backup + replication |
| **ECS** | 5 min | 0 min | Auto-scaling recovery |
| **EBS** | 15 min | 1 hour | Snapshot restore |
| **Full Region** | 2 hours | 30 min | Secondary region failover |

## Scaling Architecture

### Horizontal Scaling (ECS)

```
Auto Scaling Group (ECS Cluster)
├─ Min Instances: 1 (dev) → 3 (prod)
├─ Max Instances: 3 (dev) → 10 (prod)
├─ Target Utilization: 70% CPU
├─ Scale-up: +1 instance (5 min)
└─ Scale-down: -1 instance (15 min)
```

### Vertical Scaling (Database)

```
RDS Instance Family Progression:
dev:  t3.micro  (1 vCPU, 1 GB RAM)
  ↓
staging: t3.small  (1 vCPU, 2 GB RAM)
  ↓
uat: t3.small  (1 vCPU, 2 GB RAM)
  ↓
prod: r6g.large (2 vCPU, 16 GB RAM)
```

## Cost Optimization

### Regional Cost Allocation

| Component | Dev | Staging | UAT | Prod |
|---|---|---|---|---|
| **VPC & NAT** | $5-10 | $10-15 | $15-20 | $30-50 |
| **RDS** | $10-15 | $20-30 | $30-50 | $100-150 |
| **ECS (compute)** | $20-30 | $30-50 | $50-70 | $100-200 |
| **Networking** | $5 | $10 | $15 | $30 |
| **Storage & Backup** | $2-5 | $5-10 | $10-20 | $50-100 |
| **Monthly Total** | ~$50-70 | ~$100-150 | ~$150-200 | ~$300-500+ |

### Cost Optimization Strategies

1. **Right-sizing:** Use t3.micro in dev, scale to large in prod
2. **Reserved Instances:** 30-40% savings for prod (annual purchase)
3. **Spot Instances:** For non-critical workloads (additional 70% savings)
4. **Auto-scaling:** Reduce capacity during low-traffic periods
5. **Data Transfer:** Minimize cross-region traffic (0-0.02 per GB)

## Deployment Pipeline

```
┌────────────────────────────────────────┐
│         Development Workflow            │
├────────────────────────────────────────┤
│                                        │
│  1. Developer creates PR                │
│     └─ Terraform plan generated        │
│     └─ Plan posted as comment          │
│                                        │
│  2. Code review                        │
│     └─ Peer reviews plan output        │
│     └─ Security scan performed         │
│                                        │
│  3. Merge to main branch               │
│     └─ Trigger GitHub Actions          │
│                                        │
│  4. Auto-deploy to dev                 │
│     └─ Apply changes automatically     │
│                                        │
│  5. Manual approval for staging        │
│     └─ Requires 2 approvals            │
│     └─ Apply after approval            │
│                                        │
│  6. Manual approval for prod           │
│     └─ Requires manager + DevOps       │
│     └─ Automatic rollback on error     │
│                                        │
└────────────────────────────────────────┘
```
