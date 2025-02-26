# main.tf
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

  tags = local.tags
}

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
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-WindowsWorkspaceSG" })
}
