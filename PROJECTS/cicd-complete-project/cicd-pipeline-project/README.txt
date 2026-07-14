================================================================
   AWS CI/CD PIPELINE — COMPLETE PROJECT README
   GitHub → CodePipeline → CodeBuild → ECR → CodeDeploy → EC2
================================================================


================================================================
SECTION 1 — WHAT THIS PROJECT BUILDS
================================================================

A complete automated CI/CD pipeline on AWS. Every time you push
code to GitHub, the pipeline triggers automatically:

  1. CodePipeline detects the push (Source stage)
  2. CodeBuild pulls the code, builds a Docker image, pushes to ECR
  3. CodeDeploy pulls the image on EC2 and runs the new container
  4. Flask app is live at the EC2 public IP

Zero manual steps after the first terraform apply.

PIPELINE FLOW:
  GitHub (push to main)
      │
      │ webhook triggers
      ▼
  CodePipeline (orchestrator)
      │
      ├─ Stage 1: Source
      │     pulls code from GitHub → stores in S3 artifact bucket
      │
      ├─ Stage 2: Build (CodeBuild)
      │     reads buildspec.yml
      │     runs: docker build → docker push to ECR
      │     outputs: appspec.yml + scripts/ + imagedefinitions.json
      │
      └─ Stage 3: Deploy (CodeDeploy)
            reads appspec.yml from build output
            connects to EC2 via CodeDeploy agent
            runs lifecycle hooks:
              ApplicationStop  → stop_app.sh   (stop old container)
              BeforeInstall    → before_install.sh (ensure Docker/AWS CLI)
              ApplicationStart → start_app.sh  (pull image, run container)
              ValidateService  → validate.sh   (health check, auto-rollback)


RESOURCES CREATED:
  aws_ecr_repository            flask-cicd-app
  aws_ecr_lifecycle_policy      keep last 10 images
  aws_s3_bucket                 artifact storage between stages
  aws_iam_role x4               CodePipeline, CodeBuild, CodeDeploy, EC2
  aws_iam_role_policy x3        + 1 managed policy attachment
  aws_iam_instance_profile      for EC2
  aws_ssm_parameter x3          github_token, ecr_url, container_name
  aws_codebuild_project         builds Docker image
  aws_cloudwatch_log_group x1   CodeBuild logs
  aws_codedeploy_app            logical application
  aws_codedeploy_deployment_group  targets EC2 by tag
  aws_codepipeline              3-stage pipeline
  aws_security_group            EC2 ports 22 and 80
  aws_instance                  Flask deployment target with CodeDeploy agent


SECRETS MANAGEMENT (SSM Parameter Store):
  GitHub token → /cicd/github_token  (SecureString, KMS encrypted)
  ECR repo URL → /cicd/ecr_repo_url  (String)
  Container    → /cicd/container_name (String)

  CodeBuild reads /cicd/github_token at runtime via:
    env:
      parameter-store:
        GITHUB_TOKEN: "/cicd/github_token"

  Token is NEVER in:
    - buildspec.yml (only the SSM path is there)
    - build logs (CodeBuild redacts parameter-store values)
    - Terraform state (marked sensitive = true)
    - GitHub code (it is read from SSM at build time)


================================================================
SECTION 2 — PROJECT STRUCTURE
================================================================

cicd-pipeline-project/
├── app/
│   ├── app.py                ← Flask application
│   ├── requirements.txt      ← Flask + gunicorn
│   └── Dockerfile            ← CodeBuild builds this
│
├── scripts/                  ← CodeDeploy lifecycle hooks
│   ├── stop_app.sh           ← ApplicationStop: stop old container
│   ├── before_install.sh     ← BeforeInstall: install Docker/AWS CLI
│   ├── start_app.sh          ← ApplicationStart: pull image, run container
│   └── validate.sh           ← ValidateService: health check
│
├── buildspec.yml             ← CodeBuild instructions (root of repo)
├── appspec.yml               ← CodeDeploy instructions (root of repo)
│
├── modules/
│   ├── ecr/                  ← ECR repo + lifecycle policy
│   ├── ssm/                  ← SSM parameters for secrets
│   ├── iam/                  ← 4 IAM roles + policies
│   ├── codebuild/            ← CodeBuild project
│   ├── codedeploy/           ← CodeDeploy app + deployment group
│   ├── codepipeline/         ← S3 artifact bucket + pipeline
│   └── ec2/                  ← EC2 instance + security group
│
├── backend.tf
├── provider.tf
├── variables.tf
├── terraform.tfvars
├── main.tf
└── outputs.tf


GITHUB REPO STRUCTURE (what you push):
  flask-cicd-app/               ← your GitHub repo root
  ├── app/
  │   ├── app.py
  │   ├── requirements.txt
  │   └── Dockerfile
  ├── scripts/
  │   ├── stop_app.sh
  │   ├── before_install.sh
  │   ├── start_app.sh
  │   └── validate.sh
  ├── buildspec.yml             ← MUST be at root
  └── appspec.yml               ← MUST be at root


================================================================
SECTION 3 — PREREQUISITES
================================================================

1. GitHub repository
   Create a new public repo: flask-cicd-app
   Push all files from this project to it

2. GitHub Personal Access Token (PAT)
   GitHub → Settings → Developer settings → Personal access tokens
   → Tokens (classic) → Generate new token
   Scopes needed: repo, admin:repo_hook
   Copy the token — you only see it once

3. Store token in SSM (do this BEFORE terraform apply):
   aws ssm put-parameter \
     --name "/cicd/github_token" \
     --value "ghp_yourTokenHere" \
     --type "SecureString" \
     --region us-east-1

4. AWS key pair:
   aws ec2 create-key-pair \
     --key-name hasham-key \
     --query 'KeyMaterial' \
     --output text > ~/.ssh/hasham-key.pem
   chmod 400 ~/.ssh/hasham-key.pem

5. Set your IP in terraform.tfvars:
   curl https://checkip.amazonaws.com
   my_ip = "YOUR.IP.HERE/32"


================================================================
SECTION 4 — DEPLOYMENT STEPS
================================================================

STEP 1: Push your app code to GitHub first
  cd your-local-folder
  git init
  git remote add origin https://github.com/i-am-hasham/flask-cicd-app.git
  git add .
  git commit -m "initial commit"
  git push -u origin main

STEP 2: Store GitHub token in SSM
  aws ssm put-parameter \
    --name "/cicd/github_token" \
    --value "ghp_YOUR_TOKEN_HERE" \
    --type "SecureString" \
    --region us-east-1

STEP 3: Deploy infrastructure
  cd cicd-pipeline-project/
  terraform init
  terraform plan
  terraform apply    # type yes, takes 2-3 minutes

STEP 4: First pipeline run
  The pipeline triggers automatically when:
    - You run terraform apply (CodePipeline detects existing GitHub commits)
    OR
    - You push any new commit to the main branch

  Watch progress:
    AWS Console → CodePipeline → hasham-cicd-pipeline

  Or trigger manually:
    aws codepipeline start-pipeline-execution \
      --name hasham-cicd-pipeline \
      --region us-east-1

STEP 5: Access the app
  terraform output app_url
  # Open in browser: http://<ec2_public_ip>

  Endpoints:
    /         ← home page
    /health   ← JSON health check
    /info     ← server info


HOW TO TRIGGER A NEW DEPLOYMENT:
  Just push any change to GitHub main branch:
    echo "v2" >> app/app.py
    git add . && git commit -m "update v2" && git push

  Watch: CodePipeline console → pipeline starts in ~30 seconds


================================================================
SECTION 5 — COMPLETE CODE EXPLANATION
================================================================

----------------------------------------------------------------
buildspec.yml — What CodeBuild Does
----------------------------------------------------------------

version: 0.2

env:
  parameter-store:
    GITHUB_TOKEN: "/cicd/github_token"
  # CodeBuild fetches this from SSM automatically
  # Value never appears in build logs

phases:
  pre_build:
    commands:
      # Get ECR URI from account ID
      - AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
      - ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
      - IMAGE_URI="${ECR_URI}/${ECR_REPO_NAME}:latest"
      - IMAGE_URI_COMMIT="${ECR_URI}/${ECR_REPO_NAME}:${CODEBUILD_RESOLVED_SOURCE_VERSION}"
      # CODEBUILD_RESOLVED_SOURCE_VERSION = git commit hash
      # Tags each image with the commit that built it = traceability

      # Login to ECR
      - aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR_URI}

  build:
    commands:
      - cd app/
      - docker build -t ${IMAGE_URI} .
      - docker tag ${IMAGE_URI} ${IMAGE_URI_COMMIT}

  post_build:
    commands:
      - docker push ${IMAGE_URI}
      - docker push ${IMAGE_URI_COMMIT}
      # Two tags pushed: "latest" + commit hash

      # imagedefinitions.json tells CodeDeploy which image to pull
      - printf '[{"name":"%s","imageUri":"%s"}]' "${CONTAINER_NAME}" "${IMAGE_URI}" > imagedefinitions.json

      # deploy_vars.json read by start_app.sh on EC2
      - printf '{"image_uri":"%s","container_name":"%s","app_port":"%s"}' \
          "${IMAGE_URI}" "${CONTAINER_NAME}" "${APP_PORT}" > deploy_vars.json

artifacts:
  files:
    - appspec.yml
    - scripts/**/*
    - imagedefinitions.json
    - deploy_vars.json


----------------------------------------------------------------
appspec.yml — What CodeDeploy Does
----------------------------------------------------------------

version: 0.0
os: linux

files:
  - source: /
    destination: /home/ubuntu/cicd-app
    # Copies all artifact files to EC2

hooks:
  ApplicationStop:
    - location: scripts/stop_app.sh
      # Stops and removes old Docker container

  BeforeInstall:
    - location: scripts/before_install.sh
      # Ensures Docker + AWS CLI installed

  ApplicationStart:
    - location: scripts/start_app.sh
      # Logs into ECR, pulls image, runs container

  ValidateService:
    - location: scripts/validate.sh
      # Checks container running + app responds on /health
      # If this fails → CodeDeploy auto-rolls back


----------------------------------------------------------------
modules/iam/main.tf — Four IAM Roles
----------------------------------------------------------------

ROLE 1: CodePipeline role
  Trust: codepipeline.amazonaws.com
  Permissions:
    - s3: read/write artifact bucket
    - codebuild: start builds
    - codedeploy: create deployments
    - ssm: read parameters

ROLE 2: CodeBuild role
  Trust: codebuild.amazonaws.com
  Permissions:
    - logs: write build logs to CloudWatch
    - s3: read/write artifact bucket
    - ecr: authenticate + push images
    - ssm: read GitHub token
    - sts: get account ID

ROLE 3: CodeDeploy role
  Trust: codedeploy.amazonaws.com
  Permissions: AWSCodeDeployRole (managed policy)
  Covers all EC2 deployment operations

ROLE 4: EC2 instance role
  Trust: ec2.amazonaws.com
  Permissions:
    - ecr: pull Docker images (GetAuthorizationToken + BatchGetImage)
    - s3: read deployment artifacts
    - cloudwatch: write logs/metrics

WHY EC2 needs a role:
  start_app.sh runs "aws ecr get-login-password" to pull the image.
  The EC2 needs ECR credentials for this. Instead of storing
  access keys on the instance (insecure), the instance role
  provides temporary credentials automatically via instance metadata.


----------------------------------------------------------------
modules/codepipeline/main.tf — The Pipeline
----------------------------------------------------------------

Stage 1: Source
  Provider: GitHub (ThirdParty)
  - CodePipeline watches the GitHub repo for new commits
  - When detected: pulls code and stores it in S3 artifact bucket
  - Creates a webhook in GitHub automatically (requires repo scope on PAT)

Stage 2: Build
  Provider: CodeBuild (AWS)
  - input_artifacts = source_output (the GitHub code from Stage 1)
  - CodeBuild runs buildspec.yml
  - output_artifacts = build_output (appspec.yml + scripts + JSON files)

Stage 3: Deploy
  Provider: CodeDeploy (AWS)
  - input_artifacts = build_output (from Stage 2)
  - CodeDeploy reads appspec.yml
  - Connects to EC2 instances tagged DeploymentTarget=true
  - Runs the 4 lifecycle hook scripts


----------------------------------------------------------------
modules/ec2/main.tf — Deployment Target
----------------------------------------------------------------

user_data installs on first boot:
  1. ruby, wget (required by CodeDeploy agent installer)
  2. CodeDeploy agent (polls CodeDeploy service for jobs)
  3. Docker
  4. AWS CLI v2

WHY CodeDeploy agent matters:
  The agent is a daemon running on EC2 that continuously polls
  the CodeDeploy service. When a deployment is triggered:
    CodeDeploy service → notifies agent → agent downloads
    artifact from S3 → agent runs lifecycle hook scripts

  Without the agent installed, CodeDeploy cannot deploy to this EC2.
  The agent install takes 2-3 minutes — this is why EC2 needs
  to fully boot before you trigger the first pipeline run.

Tag: DeploymentTarget = "true"
  CodeDeploy deployment group uses this tag to find targets:
    ec2_tag_filter {
      key   = "DeploymentTarget"
      value = "true"
    }
  Any EC2 with this tag becomes a deployment target.


----------------------------------------------------------------
modules/codedeploy/main.tf — Deployment Configuration
----------------------------------------------------------------

auto_rollback_configuration:
  enabled = true
  events  = ["DEPLOYMENT_FAILURE"]

  If validate.sh exits with non-zero code:
    → CodeDeploy marks deployment FAILED
    → Triggers automatic rollback
    → Re-runs the previous successful deployment scripts
    → Old container comes back up

deployment_config_name = "CodeDeployDefault.AllAtOnce"
  Options:
    AllAtOnce  = deploy to all instances at once (fast, downtime possible)
    OneAtATime = rolling deploy, one instance at a time (no downtime)
    HalfAtATime= deploy to half, then the other half


================================================================
SECTION 6 — TROUBLESHOOTING
================================================================

PIPELINE NOT TRIGGERING:
  - Check GitHub token has repo + admin:repo_hook scopes
  - Verify SSM parameter /cicd/github_token exists:
    aws ssm get-parameter --name /cicd/github_token --region us-east-1
  - Manually trigger: aws codepipeline start-pipeline-execution --name hasham-cicd-pipeline

CODEBUILD FAILS:
  - AWS Console → CodeBuild → Build history → click failed build → view logs
  - Common causes:
      Docker permission error → check privileged_mode = true in codebuild module
      ECR login fails → check CodeBuild IAM role has ecr:GetAuthorizationToken

CODEDEPLOY FAILS:
  - AWS Console → CodeDeploy → Deployments → click failed deployment
  - View deployment lifecycle events — shows which hook failed
  - SSH to EC2:
    ssh -i ~/.ssh/hasham-key.pem ubuntu@<ec2_ip>
    sudo cat /var/log/aws/codedeploy-agent/codedeploy-agent.log
    cat /home/ubuntu/cicd-app/scripts/*.sh (check scripts are there)

  - Check CodeDeploy agent is running:
    systemctl status codedeploy-agent

APP NOT ACCESSIBLE:
  - Wait 5 minutes after first deploy (CodeDeploy agent install takes time)
  - Check container is running: docker ps
  - Check port mapping: docker ps shows 0.0.0.0:80->5000/tcp
  - Check security group allows port 80 inbound

ECR PUSH FAILS:
  - Verify ECR repo exists: aws ecr describe-repositories --region us-east-1
  - Check CodeBuild role has ecr permissions


================================================================
SECTION 7 — SCREENSHOT GUIDE FOR UPWORK PORTFOLIO
================================================================

SCREENSHOT 01 — VS Code Project Structure
  Title: "Full AWS CI/CD Pipeline — 7 Terraform Modules"
  Show: All folders expanded: app/, scripts/, modules/ecr through ec2/
  Why: Shows professional modular architecture. Most portfolios show
       one flat main.tf. Seven modules = enterprise pattern.

SCREENSHOT 02 — terraform plan Output
  Title: "terraform plan — Full Pipeline Infrastructure"
  Run: terraform plan 2>&1 | grep -E "will be created|Plan:"
  Show: List of resources + Plan: X to add line
  Why: Proves you understand what you deploy.

SCREENSHOT 03 — terraform apply Complete
  Title: "Apply Complete — CI/CD Pipeline Live"
  Show: Apply complete! line + summary output box with:
        pipeline name, ECR repo URL, EC2 IP, app URL
  Why: Deployment proof.

SCREENSHOT 04 — CodePipeline Console (Pipeline Running)
  Title: "Pipeline Triggered — All 3 Stages Running"
  Where: AWS Console → CodePipeline → hasham-cicd-pipeline
  Show: Push a commit, immediately screenshot the pipeline
        with Source (green tick), Build (in progress), Deploy (pending)
  Why: THE most impressive screenshot. Shows the full automated flow live.

SCREENSHOT 05 — CodeBuild Logs
  Title: "CodeBuild — Docker Image Built and Pushed to ECR"
  Where: CodePipeline → Build stage → click Details → View logs
  Show: The log lines showing:
          Logging into Amazon ECR...
          Building Docker image...
          Pushing to ECR...
          Push complete
  Why: Shows you understand the build process end to end.

SCREENSHOT 06 — ECR Repository with Images
  Title: "Docker Images in ECR — Tagged with Commit Hash"
  Where: AWS Console → ECR → flask-cicd-app repository
  Show: Two image tags: "latest" and a commit hash (abc1234...)
        Both pushed at the same time (same pushed date)
  Why: Shows production best practice — every image tagged
       with the commit that built it for traceability.

SCREENSHOT 07 — CodeDeploy Deployment Success
  Title: "CodeDeploy — All Lifecycle Hooks Passed"
  Where: AWS Console → CodeDeploy → Deployments → latest deployment
  Show: All 4 lifecycle events green:
          ApplicationStop       Succeeded
          BeforeInstall         Succeeded
          ApplicationStart      Succeeded
          ValidateService       Succeeded
  Why: Proves the full deployment lifecycle works including health check.

SCREENSHOT 08 — Flask App in Browser
  Title: "Flask App Live — Deployed via CI/CD Pipeline"
  Where: Browser → http://<ec2_public_ip>
  Show: The Flask home page with hostname + time
        URL bar showing the EC2 public IP
  Also show: /health endpoint returning JSON
  Why: The final proof — working app deployed through automation.

SCREENSHOT 09 — SSM Parameter Store
  Title: "Secrets in SSM — GitHub Token Never in Code"
  Where: AWS Console → Systems Manager → Parameter Store
  Show: /cicd/github_token parameter
        Type: SecureString (with lock icon)
        Value: shown as ******* (masked)
  Why: Shows security awareness. Most junior pipelines hardcode
       tokens in code. SSM Parameter Store = professional approach.

SCREENSHOT 10 — Second Deployment (Prove Automation)
  Title: "Push → Auto Deploy — Zero Manual Steps"
  Steps:
    1. Change one line in app/app.py (e.g. add a version string)
    2. git push
    3. Screenshot CodePipeline immediately showing pipeline triggered
    4. Screenshot app in browser after deploy showing the change
  Why: Most powerful portfolio screenshot pair. Shows end-to-end
       automation. Code change → live app update, no clicks needed.

UPLOAD ORDER:
  1. CodePipeline running all 3 stages  (the wow factor)
  2. Flask app in browser               (the result)
  3. ECR with commit-tagged images      (shows best practices)
  4. CodeDeploy all hooks green         (shows reliability)
  5. SSM SecureString parameter         (shows security knowledge)
  6. CodeBuild logs with docker push    (shows build process)
  7. terraform apply with summary       (deployment proof)
  8. VS Code 7-module structure         (code quality)
  9. Second auto-deploy proof           (shows automation works)
  10. terraform plan output             (thoroughness)


================================================================
SECTION 8 — UPWORK LISTING COPY
================================================================

TITLE:
Complete AWS CI/CD Pipeline — GitHub to EC2 with Terraform IaC

DESCRIPTION:
Built a complete end-to-end AWS CI/CD pipeline using Terraform
(full IaC). Every GitHub push to main automatically triggers the
pipeline: CodePipeline detects the commit, CodeBuild builds a
Docker image and pushes it to ECR (tagged with commit hash for
traceability), and CodeDeploy deploys the new container to EC2
running lifecycle hooks (stop old container → pull new image →
start new container → health check with auto-rollback on failure).

Secrets management: GitHub token stored as SecureString in SSM
Parameter Store — never in code, never in logs, never in state.
CodeBuild reads it at runtime via parameter-store env var.

Infrastructure is fully modular Terraform (7 modules: ECR, SSM,
IAM, CodeBuild, CodeDeploy, CodePipeline, EC2), remote state in
S3 with DynamoDB locking, all 4 IAM roles follow least-privilege.

SKILLS TAGS:
AWS CodePipeline, CodeBuild, CodeDeploy, ECR, Terraform, Docker,
GitHub, SSM Parameter Store, IAM, CI/CD, DevOps,
Infrastructure as Code, Flask, Python


================================================================
SECTION 9 — QUICK REFERENCE COMMANDS
================================================================

DEPLOY INFRASTRUCTURE:
  terraform init
  terraform plan
  terraform apply

MANUALLY TRIGGER PIPELINE:
  aws codepipeline start-pipeline-execution \
    --name hasham-cicd-pipeline --region us-east-1

WATCH PIPELINE STATUS:
  aws codepipeline get-pipeline-state \
    --name hasham-cicd-pipeline --region us-east-1

VIEW CODEBUILD LOGS (latest build):
  aws logs tail /aws/codebuild/hasham-cicd --follow --region us-east-1

CHECK CODEDEPLOY AGENT ON EC2:
  ssh -i ~/.ssh/hasham-key.pem ubuntu@<ec2_ip>
  systemctl status codedeploy-agent
  sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log

CHECK APP ON EC2:
  docker ps
  docker logs flask-cicd-app --tail 20
  curl http://localhost/health

LIST ECR IMAGES:
  aws ecr list-images --repository-name flask-cicd-app --region us-east-1

ROTATE GITHUB TOKEN:
  aws ssm put-parameter \
    --name "/cicd/github_token" \
    --value "ghp_NEW_TOKEN" \
    --type "SecureString" \
    --overwrite \
    --region us-east-1

DESTROY EVERYTHING:
  terraform destroy

================================================================
