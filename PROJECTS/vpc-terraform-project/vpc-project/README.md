# AWS VPC Full Network Setup — Terraform

Production-ready, fully modular AWS VPC with public/private subnets across
2 Availability Zones, HA NAT Gateways, Bastion Host, Security Groups, and
remote S3 backend with DynamoDB state locking.

---

## Architecture

```
                          INTERNET
                              │
                    ┌─────────▼─────────┐
                    │  Internet Gateway  │
                    └─────────┬─────────┘
                              │
          ┌───────────────────▼──────────────────────┐
          │                  VPC  10.0.0.0/16         │
          │                                            │
          │  ┌─────────────────────────────────────┐  │
          │  │          PUBLIC SUBNETS              │  │
          │  │                                      │  │
          │  │  us-east-1a       us-east-1b         │  │
          │  │  10.0.1.0/24      10.0.2.0/24        │  │
          │  │  ┌───────────┐    ┌───────────┐      │  │
          │  │  │  Bastion  │    │  (spare)  │      │  │
          │  │  │  Host     │    │           │      │  │
          │  │  └───────────┘    └───────────┘      │  │
          │  │  ┌───────────┐    ┌───────────┐      │  │
          │  │  │  NAT GW   │    │  NAT GW   │      │  │
          │  │  │  EIP-1    │    │  EIP-2    │      │  │
          │  └──┴─────┬─────┴────┴─────┬─────┴──┘  │
          │            │                │             │
          │  ┌─────────▼────────────────▼─────────┐  │
          │  │          PRIVATE SUBNETS             │  │
          │  │                                      │  │
          │  │  us-east-1a       us-east-1b         │  │
          │  │  10.0.10.0/24     10.0.20.0/24       │  │
          │  │  ┌───────────┐    ┌───────────┐      │  │
          │  │  │ App EC2   │    │ App EC2   │      │  │
          │  │  │ / RDS     │    │ / RDS     │      │  │
          │  │  └───────────┘    └───────────┘      │  │
          │  └─────────────────────────────────────┘  │
          └────────────────────────────────────────────┘
```

---

## Resources Created

| Resource               | Count | Purpose |
|------------------------|-------|---------|
| VPC                    | 1     | Isolated private network (10.0.0.0/16) |
| Internet Gateway       | 1     | VPC door to internet |
| Public Subnets         | 2     | Bastion, NAT GW, ALB placement |
| Private Subnets        | 2     | App servers, databases |
| Elastic IPs            | 2     | Static IPs for NAT Gateways |
| NAT Gateways           | 2     | Private subnet outbound internet (HA) |
| Public Route Table     | 1     | 0.0.0.0/0 → IGW |
| Private Route Tables   | 2     | 0.0.0.0/0 → NAT GW (per AZ) |
| Security Groups        | 3     | Bastion, Private Instances, ALB |
| Bastion Host EC2       | 1     | SSH jump server |
| S3 Bucket              | 1     | Remote Terraform state |
| DynamoDB Table         | 1     | State locking |

---

## Project Structure

```
vpc-project/
├── backend-setup/           ← Run FIRST — creates S3 + DynamoDB
│   └── main.tf
├── modules/
│   ├── vpc/                 ← VPC + Internet Gateway
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── subnets/             ← 4 Subnets + Route Tables
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── nat_gateway/         ← NAT Gateways + Elastic IPs
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security_groups/     ← All Security Groups
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── bastion/             ← Bastion Host EC2
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── backend.tf               ← Remote S3 backend config
├── provider.tf              ← AWS provider + default tags
├── main.tf                  ← Calls all modules
├── variables.tf             ← All input variables
├── outputs.tf               ← All outputs
└── terraform.tfvars         ← Your actual values
```

---

## Prerequisites

**1. AWS CLI configured**
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output (json)
```

**2. Terraform >= 1.5.0 installed**
```bash
terraform version
```

**3. SSH Key Pair created**
```bash
aws ec2 create-key-pair \
  --key-name hasham-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/hasham-key.pem

chmod 400 ~/.ssh/hasham-key.pem
```

**4. Find your public IP**
```bash
curl https://checkip.amazonaws.com
# Example: 182.191.45.12
# Set in terraform.tfvars: my_ip = "182.191.45.12/32"
```

---

## Deployment — Step by Step

### Step 1: Create Remote Backend

```bash
cd backend-setup/
terraform init
terraform apply
# Type: yes
# Saves: S3 bucket + DynamoDB table
```

### Step 2: Configure terraform.tfvars

Edit `terraform.tfvars` — set your key pair name and your IP:
```
key_pair_name = "hasham-key"
my_ip         = "182.191.45.12/32"    # your actual IP
```

### Step 3: Deploy Everything

```bash
cd ..    # back to vpc-project root
terraform init
# Terraform: "Copy state to new backend?" → yes

terraform plan
# Review: should show ~23 resources to create

terraform apply
# Type: yes
# Wait 3–5 minutes (NAT GW takes longest)
```

### Step 4: Read Your Outputs

```bash
terraform output
# bastion_public_ip    = "54.x.x.x"
# bastion_ssh_command  = "ssh -i ~/.ssh/hasham-key.pem ubuntu@54.x.x.x"
# private_subnet_ids   = ["subnet-0abc...", "subnet-0def..."]
# vpc_id               = "vpc-0abc..."
```

### Step 5: Test It

```bash
# SSH to bastion
ssh -i ~/.ssh/hasham-key.pem ubuntu@<bastion_public_ip>

# From bastion, verify you are inside the VPC
hostname          # → ip-10-0-1-xxx (public subnet range)
ip addr show      # → private IP 10.0.1.x

# Launch a test EC2 in private subnet using Console (use private_subnet_ids
# and private_instance_sg_id from outputs), then SSH to it from bastion:
ssh -i hasham-key.pem ubuntu@<private_ec2_private_ip>

# From private EC2, test NAT Gateway (outbound internet):
curl https://checkip.amazonaws.com
# → Returns NAT GW Elastic IP (not your laptop IP)
# This proves NAT Gateway is working correctly
```

---

## Using This VPC in Other Projects

Other Terraform projects can reference this VPC's outputs:

```hcl
# Read this VPC's state remotely
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "hasham-vpc-project-tfstate"
    key    = "vpc-project/terraform.tfstate"
    region = "us-east-1"
  }
}

# Use outputs in your new project
resource "aws_instance" "app_server" {
  subnet_id              = data.terraform_remote_state.vpc.outputs.private_subnet_ids[0]
  vpc_security_group_ids = [data.terraform_remote_state.vpc.outputs.private_instance_sg_id]
}
```

---

## Cleanup

```bash
# 1. Destroy all VPC resources
terraform destroy
# Type: yes

# 2. Destroy the backend (remove prevent_destroy first from backend-setup/main.tf)
cd backend-setup/
terraform destroy
```

---

## Cost Estimate

| Resource             | Cost             |
|----------------------|------------------|
| NAT Gateway × 2     | ~$0.09/hr + data |
| Bastion (t2.micro)   | Free tier eligible |
| Elastic IPs (in use) | Free while attached |
| S3 + DynamoDB        | ~$0.01/month     |
| **Total 24/7**       | **~$65-70/month** |

> **Dev tip:** Set `count = 1` in nat_gateway module to use only one NAT GW
> and save ~$32/month. Fine for development, not for production HA.
