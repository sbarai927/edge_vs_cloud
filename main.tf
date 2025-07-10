terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  tags = {
    Name = "${var.app_name}-vpc"
  }
}

# Subnets
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = "${var.aws_region}${count.index % 2 == 0 ? "a" : "b"}"
  tags = {
    Name = "${var.app_name}-public-${count.index + 1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "app" {
  name        = "${var.app_name}-sg"
  description = "Allow HTTP, HTTPS, and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS PostgreSQL Database
resource "aws_db_instance" "hr_db" {
  identifier             = "${var.app_name}-db"
  engine                 = "postgres"
  engine_version         = "17.5"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = var.db_username
  password               = var.db_password
  publicly_accessible    = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.app.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id
  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id # Ubuntu 22.04 LTS
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.app.id]
  subnet_id              = aws_subnet.public[0].id
  associate_public_ip_address = true

#  user_data              = filebase64("${path.module}/deploy.sh",{
#    db_endpoint = aws_db_instance.hr_db.endpoint
#    db_name     = "hr_management"
#    db_username = var.db_username
#    db_password = var.db_password
#    github_repo = var.github_repo
#  })
#  user_data = templatefile("${path.module}/deploy.sh", {
#    db_endpoint = aws_db_instance.hr_db.endpoint
#    db_name     = "hr_management"
#    db_username = var.db_username
#    db_password = var.db_password
#    github_repo = var.github_repo
#    django_secret_key = var.django_secret_key
#  })
  user_data = templatefile("${path.module}/deploy.sh", {
    db_url            = "postgres://hr_admin:123456789@db-url:5432/hr_management"
    django_secret_key = "your-very-secret-key"
})

  tags = {
    Name = "${var.app_name}-server"
  }
}

# SSH Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "${var.app_name}-key"
  public_key = file("${path.module}/hr-management-key.pub")  # Use relative path
}

# Load Balancer
resource "aws_lb" "app" {
  name               = "${var.app_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.app_name}-lb"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.app_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app_server.id
  port             = 80
}

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# IAM Role for EC2 Instance to push logs to CloudWatch
resource "aws_iam_role" "cloudwatch_logs_role" {
  name               = "${var.app_name}-cloudwatch-logs-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Fetch current AWS account ID
data "aws_caller_identity" "current" {}


# IAM Policy for CloudWatch Logs
resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "${var.app_name}-cloudwatch-logs-policy"
  description = "Policy to allow EC2 instance to push logs to CloudWatch"
  policy      = data.aws_iam_policy_document.cloudwatch_logs_policy.json
}

# CloudWatch Logs Permissions Policy
data "aws_iam_policy_document" "cloudwatch_logs_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/${var.app_name}-logs:*"
    ]
  }
}

# Attach the CloudWatch Logs Policy to the IAM Role
resource "aws_iam_role_policy_attachment" "cloudwatch_logs_policy_attachment" {
  role       = aws_iam_role.cloudwatch_logs_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.app_name}-instance-profile"
  role = aws_iam_role.cloudwatch_logs_role.name
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "${var.app_name}-logs"
  retention_in_days = 7
}

# CloudWatch Log Stream
resource "aws_cloudwatch_log_stream" "app_log_stream" {
  name           = "${var.app_name}-log-stream"
  log_group_name = aws_cloudwatch_log_group.app_logs.name
}

# CloudWatch Alarm for EC2 instance health
resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = "${var.app_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  dimensions = {
    InstanceId = aws_instance.app_server.id
  }

  alarm_actions = [aws_sns_topic.notification.arn]
  ok_actions    = [aws_sns_topic.notification.arn]
  insufficient_data_actions = [aws_sns_topic.notification.arn]
}


resource "aws_sns_topic" "notification" {
  name = "${var.app_name}-alarm-notifications"
}

resource "aws_budgets_budget" "monthly_budget" {
  name              = "${var.app_name}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = "80" # Set your budget limit (e.g., $50)
  limit_unit        = "USD"
  time_period_start = "2025-07-05_00:00"
  time_unit         = "ANNUALLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80 # Alert at 80% of budget
    threshold_type             = "PERCENTAGE" # REQUIRED - can be "PERCENTAGE" or "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["ahmedshahriar.raj@gmail.com"]
  }

  # You need at least one notification configuration
  # Add another notification if you want alerts at different thresholds
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 40 # $40
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["ahmedshahriar.raj@gmail.com"]
  }
}