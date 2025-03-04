Terraform AWS Kronoss Workspace | tf_aws_kronoss-wkspace

Overview

This Terraform setup configures an AWS environment with these components:

A VPC with public and private subnets using the official terraform-aws-modules/vpc/aws module.

VPC Flow Logs enabled better network monitoring.

A Transit Gateway for interconnecting VPCs.

Security Groups for Windows Workspace with predefined ingress and egress rules.

Remote Backend Storage using Amazon S3 for state management.

Files Structure
```sh
/root/tf_aws_kronoss-wkspace/
├── backend.tf         # Configures S3 backend for storing Terraform state
├── main.tf            # Defines AWS infrastructure resources
├── outputs.tf         # Outputs values for Terraform resources
├── bootstrap.sh       # Bash script for bootstrap process
├── terraform.tfvars   # Variable definitions
├── versions.tf        # Specifies Terraform and provider version constraints
```

Prerequisites

Before running Terraform, make sure you have:

Configured AWS credentials (~/.aws/credentials or environment variables)

Terraform v1.0+ installed

An S3 bucket (tf-state-*****) and DynamoDB (for state locking) were set up for the remote backend by running the bootstrap.sh script

Steps to Run: 

Clone Git Repo
```sh
git clone https://github.com/elsonpulikkan96/tf_aws_kronoss-wkspace
```
Initialize Terraform and it's backend via Bootstrap sccript:
```sh
bash bootstrap.sh
```
Apply Changes to AWS
```sh
terraform apply -auto-approve
```
Destroy Infrastructure
```sh
terraform destroy -auto-approve
```
Variables

All variables are stored in terraform.tfvars. Example:
```sh
region = "eu-west-1"
vpc_cidr = "10.0.0.0/16"
```
Outputs
Once deployed, Terraform provides the following outputs:
```sh
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "transit_gateway_id" {
  description = "The ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.id
}

output "windows_workspace_sg_id" {
  description = "The ID of the Windows Workspace Security Group"
  value       = aws_security_group.windows_workspace.id
}
```
Notes:
Verify IAM permissions for creating VPCs, Security Groups, and Transit Gateways.

Modify security group rules to limit access as required.

License:
This project is under the MIT License.
