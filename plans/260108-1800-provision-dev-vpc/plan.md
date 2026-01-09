---
title: "Provision Dev VPC"
description: "Create VPC infrastructure for dev environment using local terraform-aws-vpc module"
status: in-progress
priority: P2
effort: 1h
branch: master
tags: [infra, networking, vpc, terragrunt]
created: 2026-01-08
---

# Provision Dev VPC

## Overview

Create VPC networking infrastructure for the dev environment using the local `terraform-aws-vpc` module with Terragrunt configuration inheritance.

## Configuration Summary

| Setting | Value |
|---------|-------|
| CIDR | 10.10.0.0/16 |
| Region | us-east-1 |
| AZs | us-east-1a, us-east-1b, us-east-1c |
| Subnets | Public, Private, Database |
| NAT Gateway | Disabled (cost optimization) |
| Internet Gateway | Enabled |
| VPC Flow Logs | Disabled (dev) |

## Subnet Layout

| Type | CIDR Blocks |
|------|-------------|
| Public | 10.10.1.0/24, 10.10.2.0/24, 10.10.3.0/24 |
| Private | 10.10.11.0/24, 10.10.12.0/24, 10.10.13.0/24 |
| Database | 10.10.21.0/24, 10.10.22.0/24, 10.10.23.0/24 |

## Phases

| # | Phase | Status | Effort | Link |
|---|-------|--------|--------|------|
| 1 | Create envcommon VPC config | Done (2026-01-09 13:59) | 30m | [phase-01](./phase-01-envcommon-vpc-config.md) |
| 2 | Create dev VPC deployment | Done (2026-01-09 13:59) | 30m | [phase-02](./phase-02-dev-vpc-deployment.md) |

## Dependencies

- Bootstrap tfstate-backend must be deployed first
- Remote state (S3 + DynamoDB) configured via root.hcl

## Files to Create

1. `_envcommon/networking/vpc.hcl` - Common VPC configuration
2. `environments/dev/us-east-1/01-infra/network/vpc/terragrunt.hcl` - Dev deployment

## Pattern Reference

Follow existing `_envcommon/bootstrap/tfstate-backend.hcl` pattern for configuration inheritance.
