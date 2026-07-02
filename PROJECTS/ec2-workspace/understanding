File by File Explanation

backend.tf
hcl
terraform {
  backend "s3" {
    bucket         = "hasham-vpc-project-tfstate"
    key            = "ec2-workspaces-project/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "hasham-vpc-project-tflock"
  }
}
Same S3 bucket as VPC project. Different key — this is the only thing separating the two projects' state files inside the same bucket.
S3 bucket: hasham-vpc-project-tfstate
  ├── vpc-project/terraform.tfstate           ← VPC project
  └── ec2-workspaces-project/terraform.tfstate ← THIS project
When you have three workspaces, Terraform automatically creates:
  └── ec2-workspaces-project/
        env:/dev/terraform.tfstate
        env:/stage/terraform.tfstate
        env:/prod/terraform.tfstate
Each workspace gets its own isolated state file. Dev apply never touches prod state.

remote_state.tf
hcl
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "hasham-vpc-project-tfstate"
    key    = "vpc-project/terraform.tfstate"
    region = "us-east-1"
  }
}
This is the reuse mechanism. Instead of creating VPC, subnets, and security groups here, this file reads the VPC project's state from S3 and makes all its outputs available as:
hcl
data.terraform_remote_state.vpc.outputs.private_subnet_ids
data.terraform_remote_state.vpc.outputs.private_instance_sg_id
data.terraform_remote_state.vpc.outputs.vpc_id
No networking code duplicated anywhere in this project. The network layer is owned by the VPC project, this project just consumes it.

provider.tf
hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = terraform.workspace
      ManagedBy   = "Terraform"
      Owner       = "Hasham"
    }
  }
}
Notice Environment = terraform.workspace in default_tags. Every single resource created by this project automatically gets tagged with the current workspace name — dev, stage, or prod — without writing it in every resource block. In AWS Console you can filter by this tag and instantly see which environment a resource belongs to.

variables.tf
hcl
variable "instance_type" {
  description = "Map of workspace name -> EC2 instance type"
  type        = map(string)

  default = {
    dev   = "t2.micro"
    stage = "t2.medium"
    prod  = "t2.xlarge"
  }
}

variable "instance_count" {
  description = "Map of workspace name -> number of EC2 instances"
  type        = map(number)

  default = {
    dev   = 1
    stage = 1
    prod  = 2
  }
}
This is the core design. Two maps — one for instance type, one for count. The key in each map is the workspace name. The value is what that environment gets.
type = map(string) means a dictionary where keys and values are both strings. type = map(number) means keys are strings, values are numbers.

terraform.tfvars
hcl
aws_region    = "us-east-1"
project_name  = "hasham-ec2-ws"
ami           = "ami-0c7217cdde317cfec"
key_pair_name = "hasham-key"
Notice what is NOT here — instance_type and instance_count are missing. They use the defaults from variables.tf (the maps). You never touch this file when switching environments. The map in variables.tf is the single source of truth for per-environment config.

main.tf
hcl
module "ec2_instance" {
  source = "./modules/ec2_instance"

  ami           = var.ami
  project_name  = var.project_name
  key_pair_name = var.key_pair_name
  environment   = terraform.workspace

  instance_type  = lookup(var.instance_type, terraform.workspace, "t2.micro")
  instance_count = lookup(var.instance_count, terraform.workspace, 1)

  subnet_id = data.terraform_remote_state.vpc.outputs.private_subnet_ids[0]
  sg_id     = data.terraform_remote_state.vpc.outputs.private_instance_sg_id
}
Two things happening here:
lookup() resolution:
hcl
lookup(var.instance_type, terraform.workspace, "t2.micro")
lookup(map, key, default) — reads terraform.workspace (returns current workspace name as a string), uses it as key to find the matching value in the map, falls back to "t2.micro" if workspace name is not in the map.
When workspace is dev:
lookup({"dev"="t2.micro", "stage"="t2.medium", "prod"="t2.xlarge"}, "dev", "t2.micro")
→ "t2.micro"
When workspace is prod:
lookup({"dev"="t2.micro", "stage"="t2.medium", "prod"="t2.xlarge"}, "prod", "t2.micro")
→ "t2.xlarge"
Remote state consumption:
hcl
subnet_id = data.terraform_remote_state.vpc.outputs.private_subnet_ids[0]
sg_id     = data.terraform_remote_state.vpc.outputs.private_instance_sg_id
These come directly from the VPC project's outputs. The [0] picks the first private subnet (AZ-a). The EC2 instances land in the private subnet and get the private_instance_sg attached — same SG that was pre-wired to only accept SSH from bastion and HTTP from ALB.

modules/ec2_instance/variables.tf
hcl
variable "instance_type"  { type = string }
variable "instance_count" { type = number }
variable "subnet_id"      { type = string }
variable "sg_id"          { type = string }
variable "ami"            { type = string }
variable "key_pair_name"  { type = string }
variable "project_name"   { type = string }
variable "environment"    { type = string }
The module knows nothing about workspaces or lookup(). It just receives plain values. instance_type is already "t2.micro" or "t2.xlarge" by the time it arrives here — the resolution happened in root main.tf. This keeps the module reusable in any project, workspace-based or not.

modules/ec2_instance/main.tf
hcl
resource "aws_instance" "app" {
  count = var.instance_count

  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_id]
  key_name               = var.key_pair_name

  tags = {
    Name        = "${var.project_name}-${var.environment}-${count.index + 1}"
    Environment = var.environment
    Index       = count.index + 1
  }
}
count = var.instance_count — for dev this is 1, for prod this is 2. So prod creates two separate aws_instance.app[0] and aws_instance.app[1].
${count.index + 1} in the Name tag — instance names become:
dev:   hasham-ec2-ws-dev-1
stage: hasham-ec2-ws-stage-1
prod:  hasham-ec2-ws-prod-1
       hasham-ec2-ws-prod-2

modules/ec2_instance/outputs.tf
hcl
output "instance_ids" {
  value = aws_instance.app[*].id
}

output "private_ips" {
  value = aws_instance.app[*].private_ip
}
[*] is the splat expression — returns ALL elements as a list. For dev (count=1) it returns ["i-0abc123"]. For prod (count=2) it returns ["i-0abc123", "i-0def456"]. Works regardless of count value.

outputs.tf
hcl
output "instance_type_used" {
  value = lookup(var.instance_type, terraform.workspace, "t2.micro")
}

output "reused_vpc_id" {
  value = data.terraform_remote_state.vpc.outputs.vpc_id
}
instance_type_used runs the same lookup() again so you can see in the terminal exactly which instance type was used for this workspace run. reused_vpc_id proves the VPC project's output is being consumed — the value shown here is from the VPC project's state, not anything created in this project.

Conclusion:
This project uses Terraform workspaces to manage three completely separate environments — dev, stage,
and prod — from a single codebase without ever editing any file when switching between them; the core
mechanism is two maps in variables.tf (one for instance type, one for count) where each key is a workspace
name and each value is what that environment gets, and lookup(var.instance_type, terraform.workspace,
"t2.micro") in main.tf automatically resolves the correct value at runtime by reading terraform.workspace
(a built-in Terraform variable that returns the current workspace name as a string) and using it as the key
to pull from the map — so the exact same terraform apply command creates a t2.micro × 1 in dev, t2.medium × 1
in stage, and t2.xlarge × 2 in prod purely because the active workspace is different; each workspace gets its
own completely isolated state file in S3 under env:/dev/, env:/stage/, env:/prod/ paths so a failed prod
apply can never touch dev state; the networking layer (VPC, private subnet, security group) is not recreated
here at all — instead remote_state.tf reads the VPC project's existing state file directly from S3 and
exposes its outputs as data.terraform_remote_state.vpc.outputs.private_subnet_ids[0] and
private_instance_sg_id, which are passed straight into the ec2_instance module alongside the
lookup-resolved instance type and count; the module itself knows nothing about workspaces or lookup —
it just receives plain final values and creates count number of EC2 instances using count.index + 1 for
unique naming, and [*] splat in outputs to return all instance IDs and IPs as a list regardless of count.
