# Upwork Portfolio Screenshot Guide
## Project: Multi-Environment EC2 with Terraform Workspaces

---

## SCREENSHOT 1 — Workspace List (Terminal)
**Title:** "Three Isolated Environments from One Codebase"
**What to show:**
```bash
terraform workspace list
```
Output should show:
```
  default
* prod
  dev
  stage
```
The `*` marks the currently active workspace.

**Why it works:** Immediately proves the multi-environment structure exists.
Clients understand this instantly even without reading code.

---

## SCREENSHOT 2 — terraform.tfvars and variables.tf Side by Side (VS Code)
**Title:** "Single Source of Truth — Map-Based Environment Config"
**What to show:**
- Open `variables.tf` and `terraform.tfvars` side by side in VS Code
- Highlight the `instance_type` map block:
```hcl
default = {
  dev   = "t2.micro"
  stage = "t2.medium"
  prod  = "t2.xlarge"
}
```
- Point out that `terraform.tfvars` does NOT repeat this — proving the
  map lives in one place only

**Why it works:** Shows you understand DRY (Don't Repeat Yourself) config
design — a real differentiator from beginner Terraform code.

---

## SCREENSHOT 3 — terraform plan for dev (Terminal)
**Title:** "Plan Output — dev Workspace Resolves to t2.micro"
**What to show:**
```bash
terraform workspace select dev
terraform plan
```
Scroll to the resource block and capture:
```
+ instance_type = "t2.micro"
```
Also capture the `Plan: 1 to add, 0 to change, 0 to destroy.` line.

---

## SCREENSHOT 4 — terraform plan for prod (Terminal)
**Title:** "Same Command, Same Code — prod Resolves to t2.xlarge x2"
**What to show:**
```bash
terraform workspace select prod
terraform plan
```
Capture:
```
+ instance_type = "t2.xlarge"
```
appearing TWICE (count = 2), and:
```
Plan: 2 to add, 0 to change, 0 to destroy.
```

**Why screenshots 3 and 4 together matter most:** This is the entire
point of the project proven in two screenshots — same `terraform plan`
command, zero code changes, completely different output because only the
workspace changed. Put these two side by side in your portfolio.

---

## SCREENSHOT 5 — terraform apply Success for All 3 (Terminal, stacked)
**Title:** "All Three Environments Deployed Independently"
**What to show:** Three short clips/screenshots stacked vertically:
```
[dev]   Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
[stage] Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
[prod]  Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

---

## SCREENSHOT 6 — terraform output summary for Each Workspace
**Title:** "Per-Environment Output Verification"
**What to show:**
```bash
terraform workspace select dev
terraform output summary

terraform workspace select prod
terraform output summary
```
Capture the ASCII summary box output for at least dev and prod side by
side — shows different instance type, different count, same reused VPC ID.

---

## SCREENSHOT 7 — AWS Console: EC2 Instances Filtered by Tag
**Title:** "Three Environments Visible in AWS Console"
**What to show:**
1. EC2 → Instances
2. Add filter: `tag:Project = hasham-ec2-ws`
3. Show all instances with their `Environment` tag column visible
4. You should see: 1 instance tagged `dev`, 1 tagged `stage`, 2 tagged `prod`
5. Also show Instance Type column — t2.micro, t2.medium, t2.xlarge visible
   side by side in the same table

**Why it works:** Single AWS Console screenshot visually proves the entire
concept — different sizes per environment, all from one project.

---

## SCREENSHOT 8 — S3 State Files Per Workspace
**Title:** "Isolated State Files — No Environment Cross-Contamination"
**What to show:**
1. S3 → hasham-vpc-project-tfstate bucket
2. Navigate to: `ec2-workspaces-project/env:/`
3. Show three folders: `dev/`, `stage/`, `prod/`
4. Each containing its own `terraform.tfstate`

**Why it works:** Proves you understand workspace state isolation — a
detail many junior engineers get wrong (they assume one state file is
shared, which would corrupt all environments together).

---

## SCREENSHOT 9 — Remote State Reuse Proof
**Title:** "Reusing Existing VPC Infrastructure — No Duplicate Networking Code"
**What to show:**
```bash
terraform output reused_vpc_id
terraform output reused_subnet_id
```
Then go to AWS Console → VPC → confirm that VPC ID matches the one from
your separate `vpc-terraform-project`.

**Why it works:** This is an advanced, senior-level pattern — most
freelance portfolios show isolated one-off projects. Showing that project
B consumes project A's outputs proves you can design multi-project,
modular infrastructure the way real engineering teams do it.

---

## Upload Order

1. Workspace list (sets the stage)
2. terraform.tfvars + variables.tf side by side (the DRY config pattern)
3. plan output dev (t2.micro)
4. plan output prod (t2.xlarge x2) — directly under #3 for contrast
5. AWS Console EC2 instances table (the big visual payoff)
6. S3 isolated state files
7. Remote state reuse proof
8. apply success outputs
9. output summary per workspace

---

## Upwork Listing Copy

**Title:**
Multi-Environment AWS Infrastructure — Terraform Workspaces with Dynamic Sizing

**Description:**
Built a single Terraform codebase that manages three fully isolated
environments (dev, stage, prod) using native Terraform workspaces. Each
environment automatically receives the correct EC2 instance type and
count through a map-based `lookup()` pattern — no manual file edits or
duplicated `.tf` code when switching environments. State is fully
isolated per workspace, stored remotely in S3 with DynamoDB locking.

The project also demonstrates infrastructure composition: it consumes
network resources (VPC, private subnet, security group) from a separate
VPC project via `terraform_remote_state`, avoiding duplicate networking
code and reflecting how real engineering teams split infrastructure
ownership across projects.

**Skills tags:**
Terraform, AWS EC2, Terraform Workspaces, Infrastructure as Code, DevOps,
Remote State, Multi-Environment Deployment, Cloud Architecture
