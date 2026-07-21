================================================================
   3-TIER AWS ARCHITECTURE — TERRAFORM
   VPC + ALB + EC2 ASG + RDS Multi-AZ + CloudWatch + SNS
================================================================


================================================================
1. WHAT THIS PROJECT BUILDS
================================================================

Production-grade 3-tier architecture on AWS. Three completely
isolated network tiers — each with its own security boundary.

TIER 1: Public (ALB)
  Internet traffic enters here
  ALB distributes across EC2 instances
  Nothing else lives here

TIER 2: Private App (EC2 Auto Scaling Group)
  EC2 instances — no public IPs
  Only reachable from ALB (port 80)
  Scales out/in based on CPU
  Outbound internet via NAT Gateway (for apt install, etc.)

TIER 3: Private DB (RDS MySQL Multi-AZ)
  Deepest isolation — no internet access at all
  Only reachable from EC2 app tier (port 3306)
  Multi-AZ = primary + standby in different AZs
  Auto-failover if primary AZ fails


TRAFFIC FLOW:
  Internet
    │
    ▼
  ALB (public subnets — AZ-a and AZ-b)
    │ health checks EC2 instances
    │ routes to healthy ones only
    ▼
  EC2 instances (private app subnets — AZ-a and AZ-b)
    │ app reads/writes data
    ▼
  RDS MySQL (private db subnets — AZ-a primary, AZ-b standby)


RESOURCES CREATED:
  VPC (10.0.0.0/16)
  Internet Gateway
  Public Subnets x2          (10.0.1.0/24, 10.0.2.0/24)
  Private App Subnets x2     (10.0.10.0/24, 10.0.20.0/24)
  Private DB Subnets x2      (10.0.100.0/24, 10.0.200.0/24)
  NAT Gateways x2            (one per AZ for HA)
  Elastic IPs x2
  Route Tables x4 + associations
  ALB Security Group
  Application Load Balancer
  ALB Target Group + Listener
  App Security Group
  Launch Template
  Auto Scaling Group
  ASG Scale Out/In Policies
  CloudWatch CPU Alarms x2   (for ASG scaling)
  RDS Security Group
  DB Subnet Group
  RDS MySQL Multi-AZ instance
  SNS Topic + Email subscription
  CloudWatch Alarms x5       (ALB 5xx, latency, RDS CPU, connections, storage)
  CloudWatch Dashboard


================================================================
2. PROJECT STRUCTURE
================================================================

three-tier-project/
├── modules/
│   ├── vpc/          → 6 subnets + IGW + NAT GW + route tables
│   ├── alb/          → ALB + target group + listener + SG
│   ├── asg/          → launch template + ASG + scaling policies + CPU alarms
│   ├── rds/          → RDS Multi-AZ + db subnet group + SG
│   └── monitoring/   → SNS + CloudWatch alarms + dashboard
├── backend.tf
├── provider.tf
├── variables.tf
├── terraform.tfvars
├── main.tf
└── outputs.tf


================================================================
3. SUBNET DESIGN — WHY THREE TIERS
================================================================

Most people use two tiers (public + private). Three tiers adds
a dedicated DB subnet with even tighter isolation.

PUBLIC SUBNETS (10.0.1.0/24, 10.0.2.0/24):
  map_public_ip_on_launch = true
  Route table: 0.0.0.0/0 → Internet Gateway
  Who lives here: ALB, NAT Gateways

PRIVATE APP SUBNETS (10.0.10.0/24, 10.0.20.0/24):
  map_public_ip_on_launch = false
  Route table: 0.0.0.0/0 → NAT Gateway (same AZ)
  Who lives here: EC2 instances (ASG)
  Can reach internet OUTBOUND via NAT GW (for updates, APIs)
  CANNOT be reached from internet directly

PRIVATE DB SUBNETS (10.0.100.0/24, 10.0.200.0/24):
  map_public_ip_on_launch = false
  Route table: NO internet route at all (only local)
  Who lives here: RDS
  Cannot reach internet at all — only reachable from app tier
  Extra security: even if app EC2 is compromised, attacker
  cannot use DB subnet as exit point to internet

CODE:
  # DB route table — no routes added = local traffic only
  resource "aws_route_table" "private_db" {
    vpc_id = aws_vpc.main.id
    # no route block = only local VPC traffic allowed
  }


================================================================
4. VPC MODULE CODE — KEY PARTS
================================================================

--- Why separate route table per AZ for app subnets ---

resource "aws_route_table" "private_app" {
  count  = length(var.private_app_subnet_cidrs)  # one per AZ
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
    # same-AZ NAT GW — if AZ-a fails, AZ-b subnet uses AZ-b NAT GW
  }
}

If you used ONE shared route table pointing to ONE NAT GW:
  AZ-a NAT GW fails → BOTH app subnets lose internet
With separate route tables:
  AZ-a NAT GW fails → only AZ-a app subnet loses internet
  AZ-b app subnet keeps working via AZ-b NAT GW


================================================================
5. ALB MODULE CODE — KEY PARTS
================================================================

resource "aws_lb" "main" {
  internal           = false         # internet-facing
  load_balancer_type = "application" # Layer 7 (HTTP/HTTPS)
  subnets            = var.public_subnet_ids  # MUST be public subnets
}

resource "aws_lb_target_group" "app" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    healthy_threshold   = 2    # 2 successes = healthy
    unhealthy_threshold = 3    # 3 failures = unhealthy, removed from rotation
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

HEALTH CHECK FLOW:
  ALB pings GET / on each EC2 every 30 seconds
  3 consecutive failures → instance marked unhealthy
  ALB stops sending traffic to that instance
  ASG replaces the unhealthy instance with a new one
  2 consecutive successes on new instance → added back


================================================================
6. ASG MODULE CODE — KEY PARTS
================================================================

--- Launch Template ---

resource "aws_launch_template" "app" {
  image_id      = var.ami
  instance_type = var.instance_type

  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get install -y nginx
    systemctl start nginx
    # ... serve webpage
  EOF)
  # user_data must be base64 encoded for launch template
  # runs on EVERY new instance the ASG creates

  lifecycle {
    create_before_destroy = true
    # new instances created before old ones terminated
    # prevents downtime during launch template updates
  }
}

--- Auto Scaling Group ---

resource "aws_autoscaling_group" "app" {
  vpc_zone_identifier = var.private_app_subnet_ids  # private subnets
  target_group_arns   = [var.target_group_arn]
  # target_group_arns = auto-registers new instances with ALB
  # when ASG creates instance → ALB starts health checking it
  # when health check passes → ALB sends it traffic
  # no manual registration needed

  health_check_type         = "ELB"  # use ALB health checks (not EC2 status)
  health_check_grace_period = 300    # 5 min for nginx to start before checking

  min_size         = var.min_size      # never go below this
  max_size         = var.max_size      # never exceed this
  desired_capacity = var.desired_size  # target count

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
}

--- Scaling Policies ---

resource "aws_autoscaling_policy" "scale_out" {
  adjustment_type    = "ChangeInCapacity"
  scaling_adjustment = 1      # add 1 instance
  cooldown           = 300    # wait 5 min before scaling again
  # cooldown prevents rapid up/down oscillation
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2      # must be high for 2 consecutive periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120    # 2 minute periods
  threshold           = 70     # 70% CPU
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]
  # when alarm fires → triggers scale_out policy → adds 1 instance
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

SCALING LOGIC:
  CPU > 70% for 4 minutes (2 x 2-min periods) → add 1 instance
  CPU < 30% for 4 minutes → remove 1 instance
  Always stays between min_size and max_size
  Cooldown of 300s prevents scaling too fast

INTERVIEW QUESTION: "What is health_check_type = ELB vs EC2?"
  EC2 = ASG checks if EC2 is running (just power on/off)
  ELB = ASG uses ALB health check (is the app actually responding?)
  ELB is better — catches app crashes even when EC2 is still running


================================================================
7. RDS MODULE CODE — KEY PARTS
================================================================

resource "aws_db_instance" "main" {
  engine         = "mysql"
  instance_class = var.db_instance_class

  multi_az = true
  # Creates: primary instance in one AZ
  #          synchronous standby replica in another AZ
  # If primary AZ fails:
  #   AWS detects failure → promotes standby → updates DNS
  #   ~1-2 minutes downtime (DNS TTL)
  #   Automatic — no manual action needed

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7       # 7 days of automatic backups
  storage_encrypted       = true    # encrypt data at rest with KMS
  max_allocated_storage   = 100     # auto-grow storage up to 100 GB
  performance_insights_enabled = true  # query performance analysis
}

--- RDS Security Group ---

resource "aws_security_group" "rds" {
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.app_sg_id]  # ONLY from app EC2 instances
    # NOT cidr_blocks — SG reference means only instances with app_sg
  }
  # no egress rule = RDS cannot initiate connections outbound
}

--- DB Subnet Group ---

resource "aws_db_subnet_group" "main" {
  subnet_ids = var.private_db_subnet_ids  # both DB subnets (2 AZs)
  # RDS requires at least 2 AZs in subnet group for Multi-AZ
  # Primary goes in one subnet, standby in the other
}

INTERVIEW QUESTION: "Is RDS standby readable?"
  NO. Multi-AZ standby is ONLY for failover.
  It is synchronously replicated but NOT readable.
  If you want readable replicas use Read Replicas (separate feature).
  Multi-AZ = HA. Read Replicas = performance/scaling.


================================================================
8. MONITORING MODULE CODE — KEY PARTS
================================================================

--- SNS Topic ---

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
  # IMPORTANT: confirm the subscription email after terraform apply
  # Alarms will not send emails until confirmed
}

--- ALB 5xx Alarm ---

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10           # 10 errors in 5 minutes
  treat_missing_data  = "notBreaching"
  # no data = not an alarm (ALB might just have no traffic)
  alarm_actions = [aws_sns_topic.alerts.arn]  # sends email
  ok_actions    = [aws_sns_topic.alerts.arn]  # email when resolved
}

--- RDS CPU Alarm ---

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  metric_name = "CPUUtilization"
  namespace   = "AWS/RDS"
  threshold   = 80
  alarm_actions = [aws_sns_topic.alerts.arn]
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
}

ALARMS CREATED:
  alb_5xx       → ALB returns > 10 server errors in 5 min
  alb_latency   → response time > 2 seconds
  rds_cpu       → RDS CPU > 80%
  rds_connections → DB connections > 80
  rds_storage   → free storage < 5 GB
  cpu_high      → ASG scale out trigger (CPU > 70%)
  cpu_low       → ASG scale in trigger (CPU < 30%)


================================================================
9. ROOT MAIN.TF — HOW MODULES CONNECT
================================================================

module "vpc"        → produces: vpc_id, subnet IDs (3 types)
        │
        ▼
module "alb"        → needs: vpc_id, public_subnet_ids
                    → produces: alb_sg_id, target_group_arn, alb_arn
        │
        ▼
module "asg"        → needs: vpc_id, private_app_subnet_ids,
                              alb_sg_id, target_group_arn
                    → produces: app_sg_id, asg_name
        │
        ▼
module "rds"        → needs: vpc_id, private_db_subnet_ids, app_sg_id
                    → produces: db_endpoint, db_instance_id
        │
        ▼
module "monitoring" → needs: alb_arn, db_instance_id, asg_name
                    → produces: sns_topic_arn, dashboard_name

KEY CONNECTIONS:
  module.alb.alb_sg_id → module.asg (SG reference for ingress rule)
  module.alb.target_group_arn → module.asg (auto-register with ALB)
  module.asg.app_sg_id → module.rds (SG reference for DB ingress rule)


================================================================
10. SECURITY GROUP CHAIN
================================================================

Internet → ALB SG (80, 443 from 0.0.0.0/0)
             │
             ▼ SG reference
           App SG (80 from ALB SG only)
             │
             ▼ SG reference
           RDS SG (3306 from App SG only)

Each tier only accepts traffic from the tier above it.
Direct internet access to app or DB tier = impossible.
This is the security chain that makes 3-tier architecture secure.


================================================================
11. HIGH AVAILABILITY DESIGN
================================================================

WHAT HAPPENS IF AZ-a FAILS:

  ALB: spans both AZs, removes AZ-a instances, routes to AZ-b ✓
  NAT GW: AZ-b private subnet uses AZ-b NAT GW ✓
  ASG: AZ-a instances terminated, ASG launches replacements in AZ-b ✓
  RDS: Multi-AZ promotes AZ-b standby to primary in ~2 min ✓

Result: brief disruption, automatic recovery, no manual action.

SINGLE POINTS OF FAILURE IN THIS DESIGN: None
  ALB: AWS managed, inherently HA across AZs
  NAT GW: one per AZ, separate route tables
  EC2: min_size = 2 means always at least one per AZ
  RDS: Multi-AZ standby in second AZ


================================================================
12. DEPLOYMENT
================================================================

STEP 1: Init
  terraform init

STEP 2: Plan
  terraform plan
  # review ~35 resources to add

STEP 3: Apply
  terraform apply
  # takes 10-15 minutes (RDS Multi-AZ is slowest — ~10 min)

STEP 4: Confirm SNS email
  Check your email for AWS SNS confirmation
  Click "Confirm subscription" link
  Without this: alarms fire but no emails sent

STEP 5: Access app
  terraform output app_url
  # open in browser: http://<alb-dns-name>
  # refresh multiple times — see different instance IDs (load balancing)

STEP 6: View dashboard
  terraform output cloudwatch_dashboard
  # open in browser to see ALB, ASG, RDS metrics

CLEANUP:
  terraform destroy
  # RDS takes longest to delete (~5-10 minutes)


================================================================
13. INTERVIEW Q&A
================================================================

Q: What is the difference between ALB and NLB in this project?
A: We use ALB (Layer 7). It understands HTTP — can route by path,
   headers, host. Health checks are HTTP-based. NLB is Layer 4
   (TCP only) — faster but no HTTP awareness. For web apps ALB
   is the right choice.

Q: Why min_size = 2 in the ASG?
A: One instance per AZ. If AZ-a fails and you had min_size = 1
   with that instance in AZ-a, the ASG launches a replacement
   but takes a few minutes. With min_size = 2 (one per AZ),
   traffic immediately shifts to AZ-b instance with no wait.

Q: What is health_check_grace_period = 300?
A: New EC2 instances take time to install nginx and start serving.
   Without grace period, ALB health checks would run immediately
   after launch, see nginx not ready yet, and mark instance
   unhealthy — then ASG terminates it before it finishes starting.
   300 seconds gives nginx time to fully start.

Q: Is Multi-AZ standby readable?
A: No. Multi-AZ standby is ONLY for automatic failover.
   It is synchronously replicated but not accessible.
   For read scaling use Read Replicas (separate feature).

Q: Why does DB subnet have no internet route?
A: RDS only needs to receive connections from app tier.
   It does not need to initiate outbound connections.
   Removing the internet route adds a defense layer —
   even if RDS credentials are compromised, attacker
   cannot use RDS as an outbound pivot point.

Q: What is treat_missing_data = notBreaching on alarms?
A: If no data is coming in (e.g. ALB has zero traffic),
   CloudWatch has no metric data. notBreaching means:
   missing data is treated as normal (not an alarm condition).
   Without this setting, idle periods would trigger false alarms.

Q: What is create_before_destroy on launch template?
A: When you update the launch template, Terraform normally
   destroys old and creates new. For ASG this could mean
   all instances are terminated first then recreated — downtime.
   create_before_destroy = true creates new ones first,
   then terminates old ones — rolling update with no downtime.

Screenshot:
SS 1 — VS Code project structure
All 5 module folders expanded showing every .tf file

SS 2 — terraform plan output
Show the final line: Plan: ~35 to add, 0 to change, 0 to destroy

SS 3 — terraform apply complete
Show Apply complete! line + summary output with ALB DNS name and DB endpoint

SS 4 — AWS Console: VPC subnets
VPC → Subnets → filter by your VPC
Show all 6 subnets with their Name tags and Tier tags visible (public, app, db)

SS 5 — App in browser
Open http://<alb-dns-name> in Chrome
Show the page with Instance ID and AZ visible
Refresh a few times — show two different instance IDs appearing (proves load balancing)

SS 6 — AWS Console: Auto Scaling Group
EC2 → Auto Scaling Groups → click your ASG
Show Activity tab with instances launching
Show 2 instances in running state across different AZs

SS 7 — AWS Console: RDS Multi-AZ
RDS → Databases → click your instance
Show: Multi-AZ = Yes, Status = Available
Show the two AZs listed (primary and standby)

SS 8 — CloudWatch Dashboard
Open the dashboard URL from terraform output
Show all three graphs: ALB requests, ASG CPU, RDS CPU

SS 9 — SNS Subscription Confirmation Email
Check your email after terraform apply
Show the AWS email: "AWS Notification - Subscription Confirmation"
Show you clicked confirm and status changed to Confirmed
Where to verify: AWS Console → SNS → Topics → your topic → Subscriptions tab → Status = Confirmed
SS 10 — CloudWatch Alarms List
AWS Console → CloudWatch → Alarms → All alarms
Show all 7 alarms in the list:

hasham-3tier-alb-5xx-errors
hasham-3tier-alb-high-latency
hasham-3tier-rds-cpu-high
hasham-3tier-rds-connections-high
hasham-3tier-rds-low-storage
hasham-3tier-cpu-high
hasham-3tier-cpu-low

SS 11 — Alert Email in Inbox
To trigger a real alarm email, manually put one alarm into ALARM state:
aws cloudwatch set-alarm-state \
  --alarm-name hasham-3tier-rds-cpu-high \
  --state-value ALARM \
  --state-reason "Testing alarm for portfolio" \
  --region us-east-1
Check your email — you will receive an alert email from AWS
Screenshot your inbox showing the alarm notification email
Then reset it back:
aws cloudwatch set-alarm-state \
  --alarm-name hasham-3tier-rds-cpu-high \
  --state-value OK \
  --state-reason "Resetting after test" \
  --region us-east-1



1. App in browser — two different instance IDs (load balancing proof)
2. Alert email in inbox                (monitoring working live)
3. CloudWatch alarms list — all green  (7 alarms active)
4. RDS Multi-AZ confirmed              (HA proof)
5. terraform apply complete            (deployment proof)
6. SNS subscription confirmed          (shows proper setup)
7. All 6 subnets across 3 tiers        (architecture proof)
8. ASG with 2 instances in 2 AZs       (HA proof)
9. CloudWatch dashboard                (observability)
10. terraform plan output              (thoroughness)
11. VS Code project structure          (code quality)

================================================================
Conclusion:
This project builds a production-grade 3-tier AWS architecture using five Terraform modules — the VPC module creates six subnets across two Availability Zones (two public for ALB and NAT Gateways, two private-app for EC2 instances, two private-db for RDS with no internet route at all), the ALB module places an internet-facing Application Load Balancer in the public subnets with a target group that health-checks each EC2 every 30 seconds and automatically removes unhealthy instances from rotation, the ASG module creates a launch template and Auto Scaling Group in the private app subnets that auto-registers new instances with the ALB target group and scales out when CPU exceeds 70% for 4 consecutive minutes and scales in when it drops below 30% — always staying between the min and max size with a 5-minute cooldown to prevent oscillation, the RDS module creates a MySQL Multi-AZ instance in the deepest private subnets using a DB subnet group spanning both AZs so AWS can place the synchronous standby replica in the second AZ for automatic failover in approximately 2 minutes if the primary fails (the standby is not readable — only for failover), and the monitoring module creates an SNS topic with email subscription plus seven CloudWatch alarms watching ALB 5xx errors and latency, RDS CPU and connections and free storage, and ASG CPU for scaling — each alarm using namespace to identify the AWS service, metric_name to identify what to measure, and dimensions to filter down to the specific resource rather than all resources of that type in the account.