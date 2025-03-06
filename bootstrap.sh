#!/bin/bash
set -e

AWS_REGION="eu-west-1"  # Change this to your required region
PROJECT_NAME=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
RANDOM_SUFFIX=$(openssl rand -hex 4)
BUCKET_NAME="tf-state-${PROJECT_NAME}-${RANDOM_SUFFIX}"
TABLE_NAME="terraform-lock-${PROJECT_NAME}-${RANDOM_SUFFIX}"

# Ensure max bucket name length is 63 characters
BUCKET_NAME=$(echo "$BUCKET_NAME" | cut -c1-63)

# --- Step 1: Force Reset backend.tf to Placeholder Values ---
BACKEND_FILE="backend.tf"
cat <<EOF > "$BACKEND_FILE"
terraform {
  backend "s3" {
    bucket         = "BUCKET_PLACEHOLDER"
    key            = "PROJECT_PLACEHOLDER/terraform.tfstate"
    region         = "REGION_PLACEHOLDER"
    encrypt        = true
    dynamodb_table = "DYNAMODB_PLACEHOLDER"
  }
}
EOF

# --- Step 2: Create S3 Bucket with Retry Logic ---
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Creating S3 bucket: $BUCKET_NAME"
    if [ "$AWS_REGION" == "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME"
    else
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
fi

# --- Step 3: Wait for S3 Bucket to Become Available ---
echo "Waiting for S3 bucket to be fully available..."
for i in {1..10}; do
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        echo "S3 bucket $BUCKET_NAME is now available."
        break
    fi
    echo "Retrying S3 bucket check... ($i/10)"
    sleep 5
done

# --- Step 4: Create DynamoDB Table with Retry Logic ---
if ! aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$AWS_REGION" &>/dev/null; then
    echo "Creating DynamoDB table: $TABLE_NAME"
    for i in {1..5}; do
        aws dynamodb create-table --table-name "$TABLE_NAME" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST --region "$AWS_REGION" && break
        echo "Retrying DynamoDB table creation in 5 seconds..."
        sleep 5
    done
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$AWS_REGION"
fi

# --- Step 5: Replace Placeholders in backend.tf ---
echo "Updating backend.tf with the correct values..."
TMP_FILE=$(mktemp)
awk -v bucket="$BUCKET_NAME" \
    -v table="$TABLE_NAME" \
    -v project="$PROJECT_NAME" \
    -v region="$AWS_REGION" \
    '{gsub("BUCKET_PLACEHOLDER", bucket);
      gsub("DYNAMODB_PLACEHOLDER", table);
      gsub("PROJECT_PLACEHOLDER", project);
      gsub("REGION_PLACEHOLDER", region);
      print}' "$BACKEND_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$BACKEND_FILE"

# --- Step 6: Validate Placeholder Replacement ---
if grep -q "BUCKET_PLACEHOLDER\\|DYNAMODB_PLACEHOLDER\\|PROJECT_PLACEHOLDER\\|REGION_PLACEHOLDER" "$BACKEND_FILE"; then
    echo "Error: Placeholders in backend.tf were not replaced correctly!"
    cat "$BACKEND_FILE"
    exit 1
fi

# Debugging: Show Final backend.tf Content
echo "Updated backend.tf content:"
cat "$BACKEND_FILE"
sudo printf "\n"
# --- Step 7: Initialize Terraform Backend ---
terraform init --reconfigure
sudo printf "\n"
echo "Succefully Intiated Terraform"
sudo printf "\n"
echo "Now launch infra using : terraform apply --auto-approve:"
