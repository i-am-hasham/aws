# Flask App Deployment with Terraform Provisioners

Terraform provisions an EC2 instance inside a VPC, copies a Flask app from
your local machine using the file provisioner, installs Flask using
remote-exec, and starts the app. Flask is accessible via public IP in the
browser immediately after terraform apply completes.

---

## Architecture

```
Your Laptop
    │
    │  terraform apply
    │
    ├── file provisioner ──────────────────→ copies app.py to EC2
    ├── remote-exec provisioner ───────────→ installs Flask, starts app
    │
    ▼
AWS
    VPC (10.0.0.0/16)
    └── Public Subnet (10.0.1.0/24)
        └── EC2 t2.micro
            ├── Security Group
            │     port 22   ← SSH (for provisioners)
            │     port 5000 ← Flask app (for browser)
            │     port 80   ← HTTP (future nginx)
            ├── app.py copied here by file provisioner
            └── Flask running as background process

Browser → http://<public_ip>:5000 → Flask app
```

---

## Project Structure

```
flask-terraform-project/
├── app.py                    ← Flask app (copied to EC2 by file provisioner)
├── backend.tf                ← S3 remote state (reuses backend-setup bucket)
├── provider.tf
├── variables.tf
├── terraform.tfvars
├── main.tf                   ← EC2 with connection + file + remote-exec
├── outputs.tf
└── modules/
    ├── vpc/
    │   ├── variables.tf
    │   ├── main.tf           ← VPC + IGW + public subnet + route table
    │   └── outputs.tf
    └── security_group/
        ├── variables.tf
        ├── main.tf           ← ports 22, 5000, 80 open
        └── outputs.tf
```

---

## Provisioner Execution Order

This is exactly what happens when you run terraform apply:

```
Step 1: Terraform creates VPC, subnet, IGW, route table, SG
Step 2: Terraform creates EC2 instance
Step 3: EC2 boots up (30-60 seconds, Terraform waits)
Step 4: connection block opens SSH to EC2 public IP
Step 5: file provisioner runs
        - reads app.py from your local machine
        - SCP copies it to /home/ubuntu/app.py on EC2
Step 6: remote-exec provisioner runs commands over SSH:
        - sudo apt-get update -y
        - sudo apt-get install python3-pip python3-venv
        - python3 -m venv /home/ubuntu/flask-env
        - pip install flask
        - nohup python app.py > flask.log 2>&1 &
        - sleep 3
        - ps aux | grep python (verify it started)
Step 7: Terraform prints outputs (public IP, URL, SSH command)
```

Total time: approximately 3-4 minutes

---

## Prerequisites

Key pair must exist in AWS:
```bash
aws ec2 create-key-pair \
  --key-name hasham-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/hasham-key.pem

chmod 400 ~/.ssh/hasham-key.pem
```

Find your IP for SSH restriction:
```bash
curl https://checkip.amazonaws.com
# Set in terraform.tfvars: my_ip = "YOUR.IP.HERE/32"
```

---

## Deployment

```bash
cd flask-terraform-project/

terraform init
terraform plan
terraform apply    # type yes, wait ~3-4 minutes
```

After apply completes, copy the flask_url from outputs and open in browser.

---

## Verify It Works

In browser:
```
http://<public_ip>:5000          ← home page
http://<public_ip>:5000/health   ← health check JSON
http://<public_ip>:5000/info     ← server info JSON
```

On EC2 (SSH in to check):
```bash
ssh -i ~/.ssh/hasham-key.pem ubuntu@<public_ip>

# Check Flask process is running
ps aux | grep python

# Check Flask startup log
cat /home/ubuntu/flask.log

# Check app.py was copied correctly
cat /home/ubuntu/app.py
```

If Flask stopped (e.g. after EC2 reboot):
```bash
# Restart manually
nohup /home/ubuntu/flask-env/bin/python /home/ubuntu/app.py > /home/ubuntu/flask.log 2>&1 &
```

---

## Cleanup

```bash
terraform destroy
# Type: yes
```

This destroys EC2, security group, route table association, route table,
subnet, IGW, and VPC. The S3 backend bucket is NOT destroyed (prevent_destroy).

---

## Screenshot Guide for Upwork Portfolio

### SCREENSHOT 1 — Project Structure in VS Code
Title: "Modular Terraform with Provisioners"
Show: VS Code file tree with all folders expanded
      modules/vpc/ and modules/security_group/ visible
      app.py at root level alongside .tf files

### SCREENSHOT 2 — terraform plan Output
Title: "terraform plan — 9 Resources Including EC2 with Provisioners"
Run:  terraform plan
Show: The aws_instance.flask block in plan output
      Must show: ami, instance_type, key_name
      Also show: Plan: 9 to add, 0 to change, 0 to destroy.

### SCREENSHOT 3 — terraform apply Running (Provisioners in Action)
Title: "Provisioners Running Live — File Copy and Remote-Exec"
Run:  terraform apply
Show: The provisioner output lines as they run:
      aws_instance.flask: Provisioning with 'file'...
      aws_instance.flask: Provisioning with 'remote-exec'...
      aws_instance.flask (remote-exec): apt-get update output
      aws_instance.flask (remote-exec): Installing Flask...
This is the most unique screenshot — shows real provisioners running.

### SCREENSHOT 4 — terraform apply Complete with Outputs
Title: "Apply Complete — Flask URL Live"
Show: The summary output box showing:
      Public IP, Flask URL, SSH command
      Apply complete! Resources: 9 added

### SCREENSHOT 5 — Flask App in Browser
Title: "Flask App Live on AWS EC2 — Accessible via Public IP"
Open: http://<public_ip>:5000 in Chrome
Show: Full browser window with the Flask home page visible
      URL bar must show the EC2 public IP

### SCREENSHOT 6 — /health Endpoint in Browser
Title: "Health Check Endpoint — JSON API Response"
Open: http://<public_ip>:5000/health
Show: Browser showing the JSON response:
      {"status": "healthy", "timestamp": "..."}

### SCREENSHOT 7 — AWS Console EC2 Running
Title: "EC2 Instance Running in AWS Console"
Show: EC2 → Instances → find hasham-flask-ec2
      State: Running (green)
      Public IPv4 address visible
      Instance type: t2.micro

### SCREENSHOT 8 — SSH + app.py Verification
Title: "app.py Successfully Copied by File Provisioner"
Run on EC2:
      cat /home/ubuntu/app.py
      cat /home/ubuntu/flask.log
      ps aux | grep python
Show: All three commands and their output in terminal
      Proves: file was copied, Flask is running

### SCREENSHOT 9 — Security Group Rules in AWS Console
Title: "Security Group — Ports 22 and 5000 Open"
Show: EC2 → Security Groups → hasham-flask-sg
      Inbound rules tab
      Port 22 (SSH) and port 5000 (Flask) visible

---

## Upload Order for Upwork

1. Flask app in browser (the payoff — show result first)
2. terraform apply with provisioners running live
3. apply complete with outputs (URL, IP)
4. /health endpoint JSON
5. SSH verification (app.py + ps aux + flask.log)
6. terraform plan output
7. VS Code project structure
8. AWS Console EC2 running
9. Security group rules

---

## Upwork Listing Copy

Title:
Flask App Deployment on AWS EC2 with Terraform Provisioners

Description:
Deployed a Python Flask web application to AWS EC2 using Terraform's
file and remote-exec provisioners. Terraform provisions the complete
infrastructure (VPC, public subnet, IGW, route table, security group,
EC2) and then automatically copies the application code from the local
machine to the server and installs all dependencies over SSH — all in
a single terraform apply command with no manual steps.

Infrastructure is modular (vpc and security_group as separate reusable
modules), state is stored remotely in S3 with DynamoDB locking, and
the Flask app is accessible at the public IP on port 5000 immediately
after deployment completes.

Skills tags:
Terraform, AWS EC2, Flask, Python, Provisioners, DevOps,
Infrastructure as Code, VPC, Linux, AWS
