# Multi-Environment EC2 with Terraform Workspaces

One codebase. Three isolated environments (dev / stage / prod). Each gets
its own EC2 instance type and count automatically via `lookup()` — no manual
file editing when switching environments.

This project **reuses** the VPC, private subnet, and private security group
from the `vpc-terraform-project` instead of recreating networking resources.
It reads them via `terraform_remote_state`.

---

## Prerequisite — VPC project must be applied

This project depends on the VPC project's S3 state. If you destroyed it,
redeploy it first:

```bash
cd ../vpc-terraform-project/vpc-project/backend-setup/
terraform apply        # if S3 bucket + DynamoDB don't exist

cd ..
terraform apply        # recreates VPC, subnets, SGs, bastion
```

Once that's up, come back here.

---

## Architecture

```
                vpc-terraform-project (separate, already deployed)
                ┌─────────────────────────────────────┐
                │  VPC, Public/Private Subnets,        │
                │  NAT GW, Bastion, Security Groups    │
                │                                       │
                │  State: s3://hasham-vpc-project-tfstate/
                │         vpc-project/terraform.tfstate │
                └──────────────┬────────────────────────┘
                               │
                       read via remote_state
                               │
                               ▼
                ec2-workspaces-project (THIS project)
                ┌─────────────────────────────────────┐
                │  reads: private_subnet_ids[0]        │
                │  reads: private_instance_sg_id       │
                │                                       │
                │  workspace: dev    → t2.micro  x1    │
                │  workspace: stage  → t2.medium x1    │
                │  workspace: prod   → t2.xlarge x2    │
                │                                       │
                │  State: s3://hasham-vpc-project-tfstate/
                │     ec2-workspaces-project/terraform.tfstate (per workspace)
                └─────────────────────────────────────┘
```

---

## Project Structure

```
ec2-workspaces-project/
├── backend.tf              # reuses VPC project's S3 bucket, different key
├── remote_state.tf         # reads VPC project's outputs
├── provider.tf
├── variables.tf            # instance_type and instance_count MAPS
├── terraform.tfvars        # shared values (same across all workspaces)
├── main.tf                 # calls ec2_instance module with lookup()
├── outputs.tf
└── modules/
    └── ec2_instance/
        ├── variables.tf
        ├── main.tf          # creates count.index EC2 instances
        └── outputs.tf
```

---

## The Core Concept — lookup()

```hcl
variable "instance_type" {
  type = map(string)
  default = {
    dev   = "t2.micro"
    stage = "t2.medium"
    prod  = "t2.xlarge"
  }
}
```

```hcl
instance_type = lookup(var.instance_type, terraform.workspace, "t2.micro")
```

`terraform.workspace` returns the CURRENT workspace name as a string
(`"dev"`, `"stage"`, or `"prod"`). `lookup()` uses that as the key to pull
the matching value from the map. Third argument is a fallback if the
workspace name isn't found in the map.

Same `terraform apply` command. Different result depending only on which
workspace is currently selected.

---

## Deployment — Step by Step

### Step 1: Initialize

```bash
cd ec2-workspaces-project/
terraform init
```

### Step 2: Create the three workspaces

```bash
terraform workspace new dev
terraform workspace new stage
terraform workspace new prod
```

Verify:
```bash
terraform workspace list
#   default
# * prod
#   dev
#   stage
```

### Step 3: Deploy to dev

```bash
terraform workspace select dev
terraform plan
# Should show: instance_type = "t2.micro", count = 1

terraform apply
# Type: yes
```

### Step 4: Deploy to stage (same code, different result)

```bash
terraform workspace select stage
terraform plan
# Should show: instance_type = "t2.medium", count = 1

terraform apply
```

### Step 5: Deploy to prod

```bash
terraform workspace select prod
terraform plan
# Should show: instance_type = "t2.xlarge", count = 2

terraform apply
```

### Step 6: Verify all three exist independently

```bash
terraform workspace select dev
terraform output summary

terraform workspace select stage
terraform output summary

terraform workspace select prod
terraform output summary
```

Each workspace has its own separate state file in S3:
```
s3://hasham-vpc-project-tfstate/ec2-workspaces-project/
  env:/dev/terraform.tfstate
  env:/stage/terraform.tfstate
  env:/prod/terraform.tfstate
```

---

## Cleanup

```bash
terraform workspace select dev
terraform destroy

terraform workspace select stage
terraform destroy

terraform workspace select prod
terraform destroy

# Switch back to default before deleting workspaces
terraform workspace select default
terraform workspace delete dev
terraform workspace delete stage
terraform workspace delete prod
```

---

## Cost Note

Only dev (t2.micro) is free-tier eligible. stage (t2.medium) and prod
(t2.xlarge x2) cost real money per hour. Destroy stage/prod immediately
after taking screenshots if this is just for portfolio purposes.
