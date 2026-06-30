# Upwork Portfolio Screenshot Guide
## Project: AWS VPC Full Network Setup with Terraform

---

## OVERVIEW
This guide tells you exactly which screens to capture, in what order,
what to show in each screenshot, and what to title them.
Goal: 8-10 screenshots that tell the full story of the project.

---

## SCREENSHOT 1 — Architecture Diagram (MOST IMPORTANT)
**Title:** "Production VPC Architecture — 2 AZs, Public/Private Subnets"
**What to show:**
Draw this in draw.io (free) or use the ASCII diagram from README
Export as PNG with white background

draw.io steps:
1. Go to https://app.diagrams.net
2. Use AWS shape library (Extras → Edit Diagram or use AWS icons)
3. Draw: Internet → IGW → Public Subnets (Bastion + NAT GW) → Private Subnets
4. Color public subnets BLUE, private subnets GREEN
5. Label every component
6. Export as PNG (1920x1080 or wider)

**Why this screenshot:** Clients immediately understand what you built.
A diagram = professionalism. Most freelancers don't include one.

---

## SCREENSHOT 2 — Project Folder Structure in VS Code
**Title:** "Modular Terraform Structure — 5 Reusable Modules"
**What to show:**
- Open VS Code
- Open the vpc-project folder
- Expand ALL folders in the file tree (left sidebar)
- Make sure all module folders and .tf files are visible
- Zoom in so text is readable (Ctrl+= a few times)

**What it should look like:**
vpc-project/
├── backend-setup/
├── modules/
│   ├── vpc/
│   ├── subnets/
│   ├── nat_gateway/
│   ├── security_groups/
│   └── bastion/
├── backend.tf
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars

**Why this screenshot:** Shows you write clean, modular, professional code.
Not just one big main.tf file dumped together.

---

## SCREENSHOT 3 — terraform plan Output (Terminal)
**Title:** "terraform plan — 23 Resources to be Created"
**What to show:**
- Run: terraform plan 2>&1 | head -100
- Show the colored output with green + symbols
- Must show resource names like:
    + aws_vpc.main
    + aws_subnet.public[0]
    + aws_subnet.public[1]
    + aws_subnet.private[0]
    + aws_nat_gateway.main[0]
    etc.
- Show the final summary line:
    "Plan: 23 to add, 0 to change, 0 to destroy."

**Terminal setup for clean screenshot:**
- Use dark terminal (black bg, white text) — looks professional
- Zoom in: Ctrl+= until text fills screen nicely
- Run: terraform plan | grep -E "^\s+\+|Plan:"

**Why this screenshot:** Proves you actually ran this, it works,
and you understand what's being created.

---

## SCREENSHOT 4 — terraform apply Success (Terminal)
**Title:** "terraform apply Complete — VPC Infrastructure Live in ~3 Minutes"
**What to show:**
- The final lines of terraform apply output
- Must show green "Apply complete!" message:
    Apply complete! Resources: 23 added, 0 changed, 0 destroyed.
- Show the Outputs section below it:
    bastion_public_ip = "54.x.x.x"
    bastion_ssh_command = "ssh -i ~/.ssh/hasham-key.pem ubuntu@54.x.x.x"
    private_subnet_ids = [...]
    public_subnet_ids = [...]
    vpc_id = "vpc-0abc..."

**Why this screenshot:** THE most important proof. Green apply complete
= it actually works. Clients want to see real results.

---

## SCREENSHOT 5 — AWS Console: VPC Dashboard
**Title:** "VPC Created in AWS Console — 10.0.0.0/16"
**What to show:**
1. Log into AWS Console
2. Go to: VPC → Your VPCs
3. Find "hasham-vpc" in the list
4. Click on it to show details panel
5. Screenshot should show:
   - VPC ID
   - CIDR: 10.0.0.0/16
   - State: Available (green)
   - DNS hostnames: Enabled

**Why this screenshot:** Proves the infra exists on real AWS,
not just code on your laptop.

---

## SCREENSHOT 6 — AWS Console: Subnets View
**Title:** "4 Subnets Across 2 Availability Zones — Public and Private"
**What to show:**
1. VPC → Subnets
2. Filter by your VPC (search for "hasham-vpc")
3. You should see all 4 subnets:
   - hasham-vpc-public-subnet-1  (us-east-1a)
   - hasham-vpc-public-subnet-2  (us-east-1b)
   - hasham-vpc-private-subnet-1 (us-east-1a)
   - hasham-vpc-private-subnet-2 (us-east-1b)
4. Make columns visible: Name, Subnet ID, CIDR, AZ, Auto-assign public IP

**Best angle:** Show that public subnets have "Auto-assign public IPv4: Yes"
and private subnets have "No" — this is the key difference.

**Why this screenshot:** Shows the full subnet design across AZs visually.

---

## SCREENSHOT 7 — AWS Console: NAT Gateway
**Title:** "High-Availability NAT Gateways — One Per Availability Zone"
**What to show:**
1. VPC → NAT Gateways
2. Both NAT Gateways visible:
   - hasham-vpc-nat-gw-1 (us-east-1a) — State: Available (green)
   - hasham-vpc-nat-gw-2 (us-east-1b) — State: Available (green)
3. Show Elastic IP column — each has a different public IP

**Why this screenshot:** Shows HA design knowledge.
One NAT GW = amateur. Two NAT GWs (one per AZ) = professional.

---

## SCREENSHOT 8 — AWS Console: S3 Backend + DynamoDB
**Title:** "Remote State Backend — S3 + DynamoDB State Locking"
**What to show (split screen or two separate screenshots):**

Part A — S3:
1. S3 → Find "hasham-vpc-project-tfstate" bucket
2. Click it, go to Objects tab
3. Show: vpc-project/terraform.tfstate file exists
4. Also show: Properties → Versioning Enabled, Encryption Enabled

Part B — DynamoDB:
1. DynamoDB → Tables → "hasham-vpc-project-tflock"
2. Show it exists with status "Active"

**Why this screenshot:** Shows you understand team collaboration
and production best practices. Junior devs store state locally.
Senior engineers use remote backends.

---

## SCREENSHOT 9 — SSH to Bastion Host (Terminal)
**Title:** "Bastion Host SSH Access Verified — Secure Jump Server Working"
**What to show:**
Run these commands and screenshot the output:

ssh -i ~/.ssh/hasham-key.pem ubuntu@<bastion_public_ip>

Once inside, run:
hostname
ip addr show
curl https://checkip.amazonaws.com    ← shows NAT GW IP, not your laptop IP

The output should show:
- You are inside the bastion (hostname = ip-10-0-1-xxx)
- Bastion has private IP in 10.0.1.0/24 (public subnet range)

**Why this screenshot:** Live proof the infrastructure is functional.
SSH success = real working infra.

---

## SCREENSHOT 10 — Security Group Rules (AWS Console)
**Title:** "Least-Privilege Security Groups — SG-to-SG Reference"
**What to show:**
1. EC2 → Security Groups → Find "hasham-vpc-private-sg"
2. Click Inbound rules tab
3. Show the rule:
   - Port: 22
   - Source: sg-0abc... (hasham-vpc-bastion-sg)  ← SG reference, not CIDR

This shows the advanced technique of referencing a Security Group
as a source instead of a hardcoded IP range.

**Why this screenshot:** Shows security awareness and AWS best practices.
This is an advanced concept that impresses technical clients.

---

## BONUS — terraform output (Terminal)
**Title:** "Clean Terraform Outputs — Ready to Plug Into Next Project"
**What to show:**
Run: terraform output
Screenshot the full output showing all values.
Especially show the "summary" output block with the ASCII table.

---

## Upwork Portfolio Entry Template

**Project Title:**
AWS VPC Infrastructure — Multi-AZ Network with Terraform Modules

**Project Description (copy-paste this):**
Built a production-ready AWS VPC network from scratch using Terraform with a
modular structure. The project creates an isolated VPC (10.0.0.0/16) with
public and private subnets across 2 Availability Zones for high availability.

Key components:
• Internet Gateway for VPC internet access
• Public subnets for Bastion Host and NAT Gateways
• Private subnets for application servers and databases
• NAT Gateways (one per AZ) for private subnet outbound internet
• Bastion Host with hardened SSH access (key-only, IP-restricted)
• Least-privilege Security Groups using SG-to-SG references
• Remote S3 backend with DynamoDB state locking for team use
• All infrastructure parameterized via variables and tfvars

**Skills Tags to add:**
Terraform, AWS, VPC, Infrastructure as Code, DevOps, Cloud Architecture,
Amazon EC2, Network Security, AWS CloudFormation, Linux

---

## Screenshot Order for Portfolio Upload

Upload in this order (most impressive first):
1. Architecture Diagram        ← First impression — must be great
2. terraform apply success     ← Proof it works
3. AWS Console VPC + Subnets   ← Visual proof in AWS
4. NAT Gateway HA screenshot   ← Shows design knowledge
5. S3 Backend + DynamoDB       ← Shows production mindset
6. VS Code folder structure    ← Shows code quality
7. SSH to Bastion              ← Live demo proof
8. Security Group SG reference ← Shows security awareness
9. terraform plan output       ← Shows thoroughness
