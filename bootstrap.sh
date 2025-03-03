#!/bin/bash

set -e  # Exit immediately if a command fails

AWS_REGION="eu-west-1"
PROJECT_NAME=$(basename "$(pwd)")
TABLE_NAME="terraform-lock-${PROJECT_NAME}"

echo "Checking if DynamoDB table '$TABLE_NAME' exists..."

if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$AWS_REGION" &>/dev/null; then
    echo "DynamoDB table '$TABLE_NAME' already exists. Skipping creation."
else
    echo "Creating DynamoDB table: $TABLE_NAME..."
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION"

    echo "Waiting for DynamoDB table to become active..."
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$AWS_REGION"
    echo "DynamoDB table '$TABLE_NAME' created successfully."
fi

# Update Terraform files with the correct table name
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/CHANGE_ME/$TABLE_NAME/g" backend.tf terraform.tfvars
else
    sed -i "s/CHANGE_ME/$TABLE_NAME/g" backend.tf terraform.tfvars
fi

echo "Initializing Terraform..."
terraform init --reconfigure
echo "Bootstrap process completed successfully!"
