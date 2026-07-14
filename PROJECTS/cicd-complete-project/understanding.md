================================================================
   AWS CI/CD PIPELINE — INTERVIEW FOCUSED NOTES
   Only what matters. Code + explanation.
================================================================


================================================================
1. WHAT THIS PROJECT IS (one paragraph for interview)
================================================================

A complete AWS CI/CD pipeline built with Terraform. Every GitHub
push triggers: CodePipeline → CodeBuild builds a Docker image and
pushes to ECR → CodeDeploy pulls that image and runs it on EC2.
GitHub token is stored in SSM Parameter Store (SecureString) so it
never appears in code or logs. Seven Terraform modules, remote state
in S3, all IAM roles follow least privilege.


================================================================
2. PIPELINE FLOW (memorize this for interview)
================================================================

git push
    │
    ▼
CodePipeline (3 stages)
    │
    ├─ Stage 1: SOURCE
    │     pulls code from GitHub → stores in S3 as source_output
    │
    ├─ Stage 2: BUILD (CodeBuild)
    │     reads buildspec.yml
    │     docker build → docker push to ECR
    │     outputs: appspec.yml + scripts + deploy_vars.json
    │
    └─ Stage 3: DEPLOY (CodeDeploy)
          reads appspec.yml
          runs 4 scripts on EC2:
            stop_app.sh      → stop old container
            before_install.sh → ensure Docker + AWS CLI
            start_app.sh     → pull image from ECR, run container
            validate.sh      → health check, auto-rollback if fails


================================================================
3. SECRETS MANAGEMENT — SSM PARAMETER STORE
================================================================

WHY: GitHub token must never be in code, logs, or state file.

HOW: Store token manually in SSM BEFORE terraform apply:

  aws ssm put-parameter \
    --name "/cicd/github_token" \
    --value "ghp_YOUR_TOKEN" \
    --type "SecureString" \
    --region us-east-1

  SecureString = KMS encrypted at rest.

CodeBuild reads it at runtime via buildspec.yml:

  env:
    parameter-store:
      GITHUB_TOKEN: "/cicd/github_token"

  Value is masked in build logs automatically. Never visible.

Terraform creates the SSM parameter with this:

  resource "aws_ssm_parameter" "github_token" {
    name  = "/cicd/github_token"
    type  = "SecureString"
    value = var.github_token

    lifecycle {
      ignore_changes = [value]
      # If you rotate token manually in Console,
      # Terraform will not overwrite it on next apply
    }
  }

INTERVIEW QUESTION: "How do you handle secrets in CI/CD?"
ANSWER: SSM Parameter Store as SecureString. CodeBuild reads via
        parameter-store env block. Never in source code or logs.


================================================================
4. BUILDSPEC.YML — WHAT CODEBUILD DOES
================================================================

version: 0.2

env:
  parameter-store:
    GITHUB_TOKEN: "/cicd/github_token"  # fetched from SSM

phases:
  pre_build:
    commands:
      # Build ECR URI dynamically from account ID
      - AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
      - ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
      - IMAGE_URI="${ECR_URI}/${ECR_REPO_NAME}:latest"
      - IMAGE_URI_COMMIT="${ECR_URI}/${ECR_REPO_NAME}:${CODEBUILD_RESOLVED_SOURCE_VERSION}"
      # CODEBUILD_RESOLVED_SOURCE_VERSION = git commit hash
      # tags image with commit for traceability

      - aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR_URI}

  build:
    commands:
      - cd app/
      - docker build -t ${IMAGE_URI} --build-arg APP_VERSION=${CODEBUILD_RESOLVED_SOURCE_VERSION} .
      - docker tag ${IMAGE_URI} ${IMAGE_URI_COMMIT}

  post_build:
    commands:
      - docker push ${IMAGE_URI}
      - docker push ${IMAGE_URI_COMMIT}
      # pushes two tags: "latest" and the commit hash

      - cd ..
      - printf '[{"name":"%s","imageUri":"%s"}]' "${CONTAINER_NAME}" "${IMAGE_URI}" > imagedefinitions.json
      - printf '{"image_uri":"%s","container_name":"%s","app_port":"%s"}' "${IMAGE_URI}" "${CONTAINER_NAME}" "${APP_PORT}" > deploy_vars.json

artifacts:
  files:
    - appspec.yml
    - scripts/**/*
    - imagedefinitions.json
    - deploy_vars.json

KEY POINTS:
  - ECR_REPO_NAME is an env var set by Terraform in CodeBuild resource
  - Two image tags: "latest" always current, commit hash for traceability
  - deploy_vars.json bridges CodeBuild output to shell scripts on EC2
  - artifacts section = what gets passed to the Deploy stage


================================================================
5. CODEBUILD TERRAFORM RESOURCE — CRITICAL SETTINGS
================================================================

resource "aws_codebuild_project" "app" {
  name         = "${var.project_name}-build"
  service_role = var.codebuild_role_arn

  source {
    type      = "CODEPIPELINE"  # receives code from pipeline, not GitHub directly
    buildspec = "buildspec.yml"
  }

  artifacts {
    type = "CODEPIPELINE"  # sends output back to pipeline
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true   # REQUIRED for docker commands
    # Without this: "Cannot connect to Docker daemon" error

    environment_variable { name = "ECR_REPO_NAME";  value = var.ecr_repo_name }
    environment_variable { name = "CONTAINER_NAME"; value = var.container_name }
    environment_variable { name = "APP_PORT";       value = tostring(var.app_port) }
  }
}

INTERVIEW QUESTION: "Why privileged_mode = true?"
ANSWER: Docker inside CodeBuild requires privileged mode to access
        the Docker daemon socket. Without it docker build/push fails.


================================================================
6. APPSPEC.YML — WHAT CODEDEPLOY DOES ON EC2
================================================================

version: 0.0
os: linux

files:
  - source: /
    destination: /home/ubuntu/cicd-app
    # copies all artifact files to EC2

permissions:
  - object: /home/ubuntu/cicd-app/scripts
    mode: 755  # makes scripts executable

hooks:
  ApplicationStop:
    - location: scripts/stop_app.sh
      timeout: 30
      runas: root

  BeforeInstall:
    - location: scripts/before_install.sh
      timeout: 60
      runas: root

  ApplicationStart:
    - location: scripts/start_app.sh
      timeout: 120
      runas: root

  ValidateService:
    - location: scripts/validate.sh
      timeout: 30
      runas: root

HOOK ORDER (always this sequence):
  ApplicationStop → BeforeInstall → ApplicationStart → ValidateService

If any script exits non-zero:
  → deployment FAILS
  → auto rollback triggers (if configured)
  → previous container comes back up


================================================================
7. THE 4 DEPLOYMENT SCRIPTS
================================================================

--- stop_app.sh ---
# stops old container before new one is deployed
CONTAINER_NAME="flask-cicd-app"

if docker ps -q -f name=${CONTAINER_NAME} | grep -q .; then
    docker stop ${CONTAINER_NAME}
fi
if docker ps -aq -f name=${CONTAINER_NAME} | grep -q .; then
    docker rm ${CONTAINER_NAME}
fi

WHY two checks: first deployment has no container to stop.
Without if check: docker stop fails → hook fails → deploy fails.


--- before_install.sh ---
# ensures Docker and AWS CLI are installed
if ! command -v docker &> /dev/null; then
    apt-get install -y docker.io
    systemctl start docker && systemctl enable docker
fi
if ! command -v aws &> /dev/null; then
    # install AWS CLI v2
fi

WHY: user_data installs these on first boot, but this script
     ensures they exist on every deployment (idempotent).


--- start_app.sh ---
# reads deploy_vars.json, pulls image from ECR, runs container
DEPLOY_VARS="/home/ubuntu/cicd-app/deploy_vars.json"
IMAGE_URI=$(python3 -c "import json; d=json.load(open('${DEPLOY_VARS}')); print(d['image_uri'])")
CONTAINER_NAME=$(python3 -c "import json; d=json.load(open('${DEPLOY_VARS}')); print(d['container_name'])")
APP_PORT=$(python3 -c "import json; d=json.load(open('${DEPLOY_VARS}')); print(d['app_port'])")

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR_URI}

docker pull ${IMAGE_URI}

docker run -d \
    --name ${CONTAINER_NAME} \
    --restart unless-stopped \
    -p 80:${APP_PORT} \
    ${IMAGE_URI}

KEY: -p 80:5000 maps host port 80 to container port 5000.
     Users access http://EC2_IP (port 80), Flask runs on 5000.
     EC2 uses IAM role to call aws ecr — no access keys needed.


--- validate.sh ---
# health check — if this fails, CodeDeploy auto-rolls back
CONTAINER_NAME="flask-cicd-app"

if ! docker ps -q -f name=${CONTAINER_NAME} | grep -q .; then
    echo "Container not running"; exit 1
fi

for i in $(seq 1 10); do
    if curl -f -s http://localhost:80/health > /dev/null 2>&1; then
        echo "PASS"; break
    fi
    [ $i -eq 10 ] && exit 1   # failed after 10 retries
    sleep 3
done

INTERVIEW QUESTION: "What happens if validate.sh fails?"
ANSWER: Script exits non-zero → CodeDeploy marks deployment FAILED
        → auto_rollback_configuration triggers → CodeDeploy re-runs
        previous successful deployment → old container comes back up.


================================================================
8. IAM — 4 ROLES (know what each one can do)
================================================================

ROLE 1: CodePipeline role
  Trust: codepipeline.amazonaws.com
  Needs: S3 read/write (artifacts), codebuild:StartBuild,
         codedeploy:CreateDeployment, iam:PassRole, ssm:GetParameter

ROLE 2: CodeBuild role
  Trust: codebuild.amazonaws.com
  Needs: logs:PutLogEvents, s3 read/write (artifacts),
         ecr:GetAuthorizationToken, ecr:PutImage (scoped to repo),
         ssm:GetParameter, sts:GetCallerIdentity

ROLE 3: CodeDeploy role
  Trust: codedeploy.amazonaws.com
  Needs: AWSCodeDeployRole (AWS managed policy — covers everything)

ROLE 4: EC2 instance role
  Trust: ec2.amazonaws.com
  Needs: ecr:GetAuthorizationToken, ecr:BatchGetImage (scoped to repo),
         s3:GetObject (artifacts), logs:PutLogEvents

WHY EC2 needs a role:
  start_app.sh runs "aws ecr get-login-password" to pull the image.
  No access keys on the instance — the role provides temporary
  credentials automatically via instance metadata (169.254.169.254).

  resource "aws_iam_instance_profile" "ec2" {
    name = "${var.project_name}-ec2-profile"
    role = aws_iam_role.ec2.name
  }
  IAM role cannot attach directly to EC2.
  Must wrap in instance_profile first.
  EC2 resource uses: iam_instance_profile = var.instance_profile

INTERVIEW QUESTION: "Why Resource = '*' on some EC2 actions?"
ANSWER: EC2 Describe actions and ecr:GetAuthorizationToken do not
        support resource-level restrictions — AWS limitation.
        Where possible (ecr:PutImage, ecr:BatchGetImage) we scope
        to the specific repo ARN.


================================================================
9. CODEDEPLOY TERRAFORM RESOURCE
================================================================

resource "aws_codedeploy_deployment_group" "app" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "${var.project_name}-deployment-group"
  service_role_arn      = var.codedeploy_role_arn
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "DeploymentTarget"
      type  = "KEY_AND_VALUE"
      value = "true"
    }
  }
  # CodeDeploy finds EC2 targets by TAG not by IP or instance ID
  # EC2 must have tag DeploymentTarget=true

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

deployment_config_name options:
  AllAtOnce  = all instances simultaneously (fast, brief downtime)
  OneAtATime = one at a time (safe, no downtime, slow)
  HalfAtATime= half at a time (balance)

deployment_type options:
  IN_PLACE   = stop old, deploy on same instance, start new
  BLUE_GREEN = launch new instances, shift traffic, terminate old


================================================================
10. EC2 MODULE — WHY CodeDeploy AGENT IS CRITICAL
================================================================

resource "aws_instance" "app" {
  ami                  = var.ami
  iam_instance_profile = var.instance_profile

  tags = {
    Name             = "${var.project_name}-ec2"
    DeploymentTarget = "true"  # CodeDeploy finds this instance by this tag
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get install -y ruby wget
    cd /home/ubuntu
    wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
    chmod +x ./install && ./install auto
    systemctl start codedeploy-agent
    systemctl enable codedeploy-agent
    # also installs docker and aws cli...
  EOF
}

INTERVIEW QUESTION: "What is the CodeDeploy agent?"
ANSWER: A daemon running on EC2 that polls CodeDeploy service for
        deployment jobs. When CodeDeploy creates a deployment:
        agent notices → downloads artifact from S3 → runs lifecycle
        scripts → reports success/failure back to CodeDeploy.
        Without it: CodeDeploy waits, times out, deployment fails.

IMPORTANT: EC2 takes 3-5 minutes to finish user_data on first boot.
           Wait before triggering the first pipeline run.


================================================================
11. CODEPIPELINE ARTIFACT FLOW
================================================================

resource "aws_codepipeline" "app" {
  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      output_artifacts = ["source_output"]  # name for GitHub code in S3
      configuration = {
        Owner      = var.github_owner
        Repo       = var.github_repo
        Branch     = var.github_branch
        OAuthToken = var.github_token
        # OAuthToken makes CodePipeline create a GitHub webhook
        # Webhook fires on every push → pipeline auto-triggers
      }
    }
  }

  stage {
    name = "Build"
    action {
      input_artifacts  = ["source_output"]  # reads GitHub code
      output_artifacts = ["build_output"]   # produces appspec + scripts + JSON
      configuration = { ProjectName = var.codebuild_project_name }
    }
  }

  stage {
    name = "Deploy"
    action {
      input_artifacts = ["build_output"]  # reads appspec.yml + scripts
      configuration = {
        ApplicationName     = var.codedeploy_app_name
        DeploymentGroupName = var.codedeploy_deployment_group
      }
    }
  }
}

source_output and build_output are just NAMES for S3 objects.
S3 is the pipe between stages.
Each stage reads input from S3, does work, writes output to S3.

force_destroy = true on S3 artifact bucket:
  Without it: terraform destroy fails if bucket has files.
  With it: Terraform empties bucket then deletes it.


================================================================
12. ECR MODULE
================================================================

resource "aws_ecr_repository" "app" {
  name                 = var.repo_name
  image_tag_mutability = "MUTABLE"
  # MUTABLE = can overwrite "latest" tag each push

  image_scanning_configuration {
    scan_on_push = true
    # auto CVE scan on every push
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      selection = { tagStatus = "any"; countType = "imageCountMoreThan"; countNumber = 10 }
      action = { type = "expire" }
    }]
  })
}
# keeps last 10 images, auto-deletes older ones
# without this: 100 builds = 100 images = storage costs accumulate

INTERVIEW QUESTION: "Why tag images with commit hash?"
ANSWER: If production breaks you know exactly which commit caused it.
        "latest" always points to current, commit hash is permanent.
        Roll back by deploying the specific commit-hash-tagged image.


================================================================
13. INTERVIEW Q&A
================================================================

Q: What is the difference between CodePipeline, CodeBuild, CodeDeploy?
A: Pipeline = orchestrator, triggers and connects stages.
   CodeBuild = build worker, runs commands in a managed container.
   CodeDeploy = deploy worker, runs scripts on your EC2 instances.

Q: How does CodePipeline detect a GitHub push?
A: OAuthToken in Source stage config causes CodePipeline to create
   a GitHub webhook. Webhook fires on every push to the branch.
   Pipeline auto-triggers within 30 seconds of a push.

Q: How does CodeDeploy find which EC2 to deploy to?
A: By EC2 tag. deployment_group has ec2_tag_filter for
   DeploymentTarget=true. Any EC2 with that tag gets deployments.
   No IPs or instance IDs hardcoded.

Q: What happens if the health check fails after deployment?
A: validate.sh exits non-zero → CodeDeploy marks deployment FAILED
   → auto_rollback_configuration triggers → previous deployment
   scripts re-run → old container comes back up automatically.

Q: Why does EC2 need an IAM role?
A: start_app.sh runs aws ecr get-login-password to pull the Docker
   image. Instead of storing access keys on the instance, the role
   provides temporary credentials via instance metadata endpoint.
   No secrets on the server.

Q: What is privileged_mode in CodeBuild?
A: Required for running Docker commands inside CodeBuild.
   Without it, Docker cannot access the daemon socket.
   Setting: privileged_mode = true in environment block.

Q: Why is the artifact S3 bucket needed?
A: CodePipeline passes data between stages via S3. Source stage
   puts GitHub code there, Build stage reads it and puts built
   artifacts there, Deploy stage reads those artifacts.
   S3 is the pipe connecting the three stages.

Q: What is deploy_vars.json?
A: JSON file written by CodeBuild containing image URI, container
   name, and port. Copied to EC2 by CodeDeploy. Read by start_app.sh
   using python3 to know which image to pull and how to run it.

Q: Why does CodeDeploy need iam:PassRole?
A: CodePipeline passes the CodeDeploy service role to CodeDeploy
   when creating a deployment. IAM PassRole permission is required
   whenever one service passes a role to another service.

================================================================
This project builds a complete AWS CI/CD pipeline where every GitHub push automatically triggers CodePipeline which runs three stages — Source pulls the code from GitHub and stores it in S3, Build runs CodeBuild which reads buildspec.yml to build a Docker image and push it to ECR with two tags (latest and commit hash for traceability), and Deploy runs CodeDeploy which connects to the EC2 via a daemon agent, copies the artifacts, and runs four lifecycle scripts in order (stop old container, ensure prerequisites, pull new image from ECR and start container, health check with auto-rollback if it fails) — the entire infrastructure is provisioned by seven Terraform modules covering ECR, SSM, IAM, CodeBuild, CodeDeploy, CodePipeline, and EC2, with the GitHub token stored as a KMS-encrypted SecureString in SSM Parameter Store so it never appears in code, logs, or state files, four separate IAM roles following least privilege (one each for CodePipeline, CodeBuild, CodeDeploy, and EC2), the EC2 instance found by CodeDeploy via a tag rather than hardcoded IP, and all pipeline artifacts passing between stages through a private S3 bucket with the entire state managed remotely in S3 with DynamoDB locking.

Note: To make pipeline trigger on git push you have to first go to developer tool > setting > connection in aws after terraform apply then there will be one in pending click on that and update and then add github app something like that option than select all and then select again what was selected then save and then connect.
Now if you will git push it , pipeline will trigger.