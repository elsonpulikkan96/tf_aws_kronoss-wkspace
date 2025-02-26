### main.tf ###
provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

locals {
  name     = "ex-${basename(path.cwd)}"
  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = {
    Project = local.name
    Owner   = "Terraform"
  }
}

# IAM Role for VPC Flow Logs
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
  description = "Allows VPC Flow Logs to publish to CloudWatch"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_flow_logs_attachment" {
  policy_arn = aws_iam_policy.vpc_flow_logs_policy.arn
  role       = aws_iam_role.vpc_flow_logs_role.name
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc-flow-logs"
  retention_in_days = 30
}

# VPC Module
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
  enable_flow_log      = true

  flow_log_destination_arn         = aws_cloudwatch_log_group.vpc_flow_logs.arn
  flow_log_cloudwatch_iam_role_arn = aws_iam_role.vpc_flow_logs_role.arn

  tags = local.tags
}

# Transit Gateway
resource "aws_ec2_transit_gateway" "this" {
  description = "Transit Gateway for VPC ${module.vpc.vpc_id}"
  tags        = merge(local.tags, { Name = "${local.name}-TGW" })
}

# Security Group
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
