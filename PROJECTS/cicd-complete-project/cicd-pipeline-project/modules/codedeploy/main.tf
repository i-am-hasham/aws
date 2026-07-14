##############################################################
# modules/codedeploy/main.tf
# Creates:
#   Application    — the logical CodeDeploy application
#   Deployment Group — target EC2 instances + deployment config
##############################################################

resource "aws_codedeploy_app" "app" {
  name             = "${var.project_name}-app"
  compute_platform = "Server"   # EC2/on-premises (not ECS or Lambda)
}

resource "aws_codedeploy_deployment_group" "app" {
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "${var.project_name}-deployment-group"
  service_role_arn       = var.codedeploy_role_arn
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  # AllAtOnce = deploy to all instances simultaneously
  # OneAtATime = rolling deployment (safer for production)
  # HalfAtATime = deploy to half at a time

  # Find target EC2 instances by tag
  ec2_tag_set {
    ec2_tag_filter {
      key   = "DeploymentTarget"
      type  = "KEY_AND_VALUE"
      value = "true"
    }
  }

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
    # IN_PLACE = deploy on existing instances (stop old, start new)
    # BLUE_GREEN = spin up new instances, shift traffic, terminate old
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
    # If deployment fails (validate.sh returns non-zero), auto rollback
    # CodeDeploy re-runs the previous successful deployment scripts
  }
}
