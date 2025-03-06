Terraform AWS Kronoss Workspace Project

Overview:

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

Outputs will displacyed with neccessary information after deployment.

Notes:
Verify IAM permissions for creating VPCs, Security Groups, and Transit Gateways.

Modify security group rules to limit access as required.

License:
This project is under the MIT License.
