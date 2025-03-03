provider "aws" {
  region = var.region
}

# Fetch available AZs
data "aws_availability_zones" "available" {}

locals {
  name     = "ex-${replace(basename(path.cwd), "_", "-")}"
  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = {
    Project = local.name
    Owner   = "Terraform"
  }
}

# ✅ VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name            = local.name
  cidr            = local.vpc_cidr
  azs             = local.azs
  private_subnets = [for index, az in local.azs : cidrsubnet(local.vpc_cidr, 4, index)]
  public_subnets  = [for index, az in local.azs : cidrsubnet(local.vpc_cidr, 4, index + 3)]

  enable_dns_support   = true
  enable_dns_hostnames = true
  enable_flow_log      = false  # Disabled here, manually defined below.

  tags = local.tags
}

# ✅ Transit Gateway
resource "aws_ec2_transit_gateway" "this" {
  description = "Transit Gateway for VPC ${module.vpc.vpc_id}"
  tags        = merge(local.tags, { Name = "${local.name}-TGW" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  vpc_id             = module.vpc.vpc_id
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  subnet_ids         = module.vpc.private_subnets

  tags = merge(local.tags, { Name = "${local.name}-TGW-Attachment" })
}

# ✅ IAM Role for VPC Flow Logs (Required for CloudWatch)
resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "vpc_flow_logs_policy" {
  name        = "vpc-flow-logs-policy"
  description = "Allows VPC Flow Logs to publish to CloudWatch Logs"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = aws_cloudwatch_log_group.vpc_flow_logs.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_flow_logs_attachment" {
  policy_arn = aws_iam_policy.vpc_flow_logs_policy.arn
  role       = aws_iam_role.vpc_flow_logs_role.name
}

# ✅ CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc-flow-logs"
  retention_in_days = 30
}

# ✅ S3 Bucket for VPC Flow Logs (No ACL Required)
resource "random_id" "s3_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "vpc_flow_logs" {
  bucket = "vpc-flow-logs-${replace(local.name, "_", "-")}-${random_id.s3_suffix.hex}"
}

resource "aws_s3_bucket_policy" "vpc_flow_logs_policy" {
  bucket = aws_s3_bucket.vpc_flow_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.vpc_flow_logs.arn}/*"
    }]
  })
}

# ✅ Attach Flow Logs to VPC (CloudWatch) [Fix Applied]
resource "aws_flow_log" "vpc_logs" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = module.vpc.vpc_id
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn  # ✅ FIXED: Required for CloudWatch
  depends_on           = [aws_iam_role_policy_attachment.vpc_flow_logs_attachment]  # Ensures IAM role is created first
}

resource "aws_flow_log" "vpc_logs_s3" {
  log_destination      = aws_s3_bucket.vpc_flow_logs.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = module.vpc.vpc_id
}

resource "aws_security_group" "windows_workspace" {
  name        = "${local.name}-win-ws-sg"
  description = "Security group for Windows Workspace allowing RDP and SMB."
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SMB"
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-WindowsWorkspaceSG" })
}

