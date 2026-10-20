# Terraform HA & Disaster Recovery Platform

> **Status:** In progress\
> **Environment:** Local development with Terraform and LocalStack\
> **AWS region configured:** `ap-south-1`

A hands-on Infrastructure as Code (IaC) project that builds a multi-AZ
AWS-style network foundation using reusable Terraform modules. The
project is being developed incrementally to demonstrate infrastructure
design, repeatable deployments, change review, and disaster-recovery
planning.

> **Important:** This project currently targets LocalStack for local
> development. LocalStack is an AWS service emulator; behavior and
> service support can differ from real AWS. Do not treat a successful
> local deployment as proof of production readiness or real-world
> disaster recovery.

## Table of Contents

-   [Project Goals](#project-goals)
-   [Current Implementation](#current-implementation)
-   [Architecture](#architecture)
-   [Repository Structure](#repository-structure)
-   [Technology Stack](#technology-stack)
-   [Prerequisites](#prerequisites)
-   [Configuration](#configuration)
-   [Getting Started](#getting-started)
-   [Terraform Workflow](#terraform-workflow)
-   [Git and Collaboration Workflow](#git-and-collaboration-workflow)
-   [Security and Cost Notes](#security-and-cost-notes)
-   [Roadmap](#roadmap)
-   [Troubleshooting](#troubleshooting)
-   [Contributing](#contributing)
-   [License](#license)

## Project Goals

-   Define infrastructure declaratively with Terraform.
-   Organize infrastructure into reusable modules.
-   Design a VPC spanning two Availability Zones.
-   Separate public, application-private, and database subnets.
-   Configure internet routing for public subnets and NAT routing for
    private application subnets.
-   Keep database subnets without a default internet route.
-   Develop a controlled workflow using formatting, validation, plans,
    commits, and pushes.
-   Extend the foundation with high availability, state management,
    monitoring, and disaster-recovery practices.

## Current Implementation

The VPC module is intended to define these resources:

-   One VPC (`10.0.0.0/16`)
-   One Internet Gateway
-   Two public subnets
-   Two private application subnets
-   Two database subnets
-   Public route table and subnet associations
-   Private route tables and subnet associations
-   Database route tables and subnet associations
-   Elastic IPs and NAT Gateways, one per configured Availability Zone

**Implementation status:** The Terraform configuration has previously
passed `terraform validate`. Always run validation again after changes.
Resource creation in LocalStack has not been confirmed by this README,
and service compatibility must be tested before relying on NAT Gateway
or Elastic IP behavior.

## Architecture

``` text
                         VPC: 10.0.0.0/16
                    /                            \
             AZ: ap-south-1a                AZ: ap-south-1b
            -----------------              -----------------
            Public subnet                 Public subnet
            10.0.1.0/24                   10.0.2.0/24
                 |                              |
            NAT Gateway                    NAT Gateway
                 |                              |
            Private app subnet             Private app subnet
            10.0.11.0/24                   10.0.12.0/24

            Database subnet                Database subnet
            10.0.21.0/24                   10.0.22.0/24
            No default internet route      No default internet route

       Public subnet default route: 0.0.0.0/0 -> Internet Gateway
       Private app subnet default route: 0.0.0.0/0 -> NAT Gateway
```

This diagram represents the intended network design, not a claim that
resources are currently deployed.

### Network design notes

-   **Public subnets** have a route to the Internet Gateway. A route
    alone does not make a workload safe or publicly reachable; security
    groups, network ACLs, public addressing, and workload configuration
    also matter.
-   **Private application subnets** use NAT Gateways for outbound IPv4
    access, if NAT resources are supported and deployed correctly.
-   **Database subnets** have no default internet route in the current
    module. Database access controls and private connectivity still need
    to be designed.
-   **Multi-AZ:** Spreading subnets across two AZs is a foundation for
    high availability, but application replicas, load balancing, data
    replication, and recovery procedures are also required.

## Repository Structure

``` text
Terraform-HA-Disaster Recovery/
├── environments/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── terraform.tfvars
├── modules/
│   └── vpc/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── .gitignore
└── README.md
```

The exact repository may contain additional files. Do not commit
`.terraform/`, state files, saved plan files, or secrets.

-   `environments/dev/`: root configuration for the development
    environment.
-   `modules/vpc/`: reusable VPC and networking resources.
-   `terraform.tfvars`: development-specific input values.
-   `versions.tf`: Terraform/provider requirements and LocalStack
    endpoint configuration.

## Technology Stack

  Tool                         Purpose
  ---------------------------- ---------------------------------------
  Terraform                    Infrastructure as Code
  AWS provider for Terraform   Declares AWS-compatible resources
  LocalStack                   Local emulator for supported AWS APIs
  Docker                       Runs LocalStack
  Git and GitHub               Version control and collaboration

## Prerequisites

Install and verify:

-   Terraform `>= 1.6.0`
-   Docker
-   Git
-   `curl`

Check versions:

``` bash
terraform version
docker --version
git --version
```

## Configuration

The development values are held in `environments/dev/terraform.tfvars`.
Current expected values:

``` hcl
environment  = "dev"
project_name = "ha-dr-platform"
aws_region   = "ap-south-1"

vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "ap-south-1a",
  "ap-south-1b"
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24"
]

database_subnet_cidrs = [
  "10.0.21.0/24",
  "10.0.22.0/24"
]
```

These AZ names and the region are configuration values. LocalStack may
not enforce every regional/AZ constraint exactly as AWS does.

## Getting Started

### 1. Go to the development root

``` bash
cd ~/Desktop/"Terraform-HA-Disaster Recovery"/environments/dev
```

All Terraform commands below are intended to run from this directory
unless stated otherwise.

### 2. Start LocalStack

If a `localstack` container is not already running:

``` bash
docker run -d \
  --name localstack \
  -p 4566:4566 \
  -e SERVICES=ec2,s3,iam,sts \
  -e PERSISTENCE=0 \
  localstack/localstack:3
```

Check container status and health:

``` bash
docker ps --filter name=localstack
curl -s http://localhost:4566/_localstack/health
```

Inspect logs if needed:

``` bash
docker logs --tail 100 localstack
```

The current provider configuration routes selected AWS API endpoints to
`http://localhost:4566`. Confirm that every required resource type is
supported by the LocalStack edition/version in use. NAT Gateway and
Elastic IP behavior may require additional verification.

### 3. Format and initialize

From `environments/dev/`:

``` bash
terraform fmt -recursive ../..
terraform init
terraform validate
```

`terraform fmt -recursive ../..` traverses a broader directory tree than
this project and can format files in neighboring projects. Prefer the
project root as the formatting scope:

``` bash
cd ~/Desktop/"Terraform-HA-Disaster Recovery"
terraform fmt -recursive .
cd environments/dev
```

Then initialize and validate:

``` bash
terraform init
terraform validate
```

Run formatting and validation after editing Terraform files.

### 4. Review the plan

``` bash
terraform plan
```

Read the proposed changes carefully before applying. If Terraform state
has been deleted, Terraform may propose recreating resources even if
resources still exist in the target environment. Confirm the target
endpoint and inspect for conflicts first.

### 5. Apply only after review

``` bash
terraform apply
```

Review the plan and confirm only when you understand the changes and
have verified that Terraform is targeting LocalStack, not real AWS. This
project's provider endpoints are configured for LocalStack, but always
inspect the active configuration before applying.

### 6. Inspect outputs and resources

``` bash
terraform output
```

The exact outputs depend on `modules/vpc/outputs.tf` and
`environments/dev/outputs.tf`. Use LocalStack-aware AWS CLI commands
only if the AWS CLI is installed and configured to target LocalStack
explicitly.

### 7. Destroy local test resources when finished

Only if you intend to remove resources managed by this Terraform state:

``` bash
terraform destroy
```

Review the proposed deletions before confirming. Destroying resources
does not replace the need to protect valuable state and source code.

## Terraform Workflow

Use this sequence for routine changes:

1.  Create or switch to a focused feature branch.
2.  Edit a small, logical set of files.
3.  Format the changed Terraform code.
4.  Run `terraform init` when the working directory or dependencies
    require it.
5.  Run `terraform validate`.
6.  Review `terraform plan`.
7.  Check `git diff` and `git status`.
8.  Commit only the intended source files.
9.  Push the feature branch.
10. Open a pull request and review changes before merging.

Useful review commands:

``` bash
git status --short
git diff
git diff --check
git branch --show-current
```

Do not commit Terraform state, saved plan files, credentials,
`.terraform/`, or local override files.

## Git and Collaboration Workflow

Use descriptive branch names, for example:

``` text
feature/network-routing
feature/remote-state
feature/autoscaling-alb
feature/monitoring
docs/architecture-readme
```

Example commit messages:

``` text
feat: create multi-AZ VPC foundation
fix: correct private subnet routing
feat: configure remote Terraform state
docs: document network architecture
```

Example push:

``` bash
git add README.md
git commit -m "docs: add project README"
git push -u origin <your-branch-name>
```

Replace `<your-branch-name>` with the actual branch name. Before
staging, review `git status` and stage only the files intended for that
commit. In a team setting, use a pull request and required checks rather
than pushing directly to the protected default branch.

## Security and Cost Notes

-   LocalStack is intended here to reduce the need for real AWS
    resources during development. It does not prove that a design is
    secure or production-ready.
-   Keep AWS credentials, access keys, tokens, passwords, and secrets
    out of Git.
-   Do not commit `terraform.tfstate`, state backups, or saved plans;
    they may contain sensitive values.
-   Do not assume Terraform is targeting LocalStack solely because a
    container is running. Review the provider endpoints before applying.
-   LocalStack itself runs in Docker and consumes local CPU, memory,
    storage, and network resources.
-   Before deploying to real AWS, review the plan, IAM permissions,
    network exposure, encryption, logging, backup retention, and
    expected charges.

## Roadmap

-   [x] Define a reusable VPC module and development environment
    configuration
-   [x] Configure two Availability Zones and public/private/database
    subnet CIDRs
-   [ ] Verify LocalStack compatibility for all networking resources
-   [ ] Deploy and test the VPC foundation locally
-   [ ] Add and validate security groups and application-tier design
-   [ ] Add launch templates, Auto Scaling, and a load balancer where
    supported
-   [ ] Configure remote state, S3 versioning, and state locking with
    verified backend support
-   [ ] Add monitoring, logging, and alerting
-   [ ] Design backup and disaster-recovery procedures, including
    recovery testing
-   [ ] Add CI checks for formatting, validation, and plan review
-   [ ] Add architecture diagrams, test evidence, and deployment
    screenshots

Update this checklist as each item is actually implemented and tested.
Do not mark a feature complete merely because its Terraform code exists.

## Troubleshooting

### Terraform says initialization is required

From `environments/dev/`:

``` bash
terraform init
```

### LocalStack health check fails

``` bash
docker ps -a --filter name=localstack
docker logs --tail 100 localstack
curl -s http://localhost:4566/_localstack/health
```

### Terraform plan proposes unexpected resource creation

Check the working directory, state status, provider endpoint
configuration, and any resources that may already exist in LocalStack.
Do not apply until the plan is understood.

### Formatting appears to affect another project

Run formatting from this repository's root with
`terraform fmt -recursive .`, not from a directory where `../..`
includes neighboring repositories.

## Contributing

For project changes:

1.  Use a focused feature branch.
2.  Keep modules reusable and environment-specific values outside shared
    module code.
3.  Run formatting and validation.
4.  Review the complete diff and plan.
5.  Document architectural or operational changes.
6.  Open a pull request for review.

## License

No license has been selected yet. Add a `LICENSE` file and update this
section if you intend to publish the project for reuse.
