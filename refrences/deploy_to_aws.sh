#!/bin/bash

# ============================================================================
# AWS Bedrock Integration Deployment Script
# This script automates the deployment of school monitoring Bedrock integration
# ============================================================================

set -e  # Exit on error

echo "========================================="
echo "School Monitoring Bedrock Deployment"
echo "========================================="
echo ""

# Configuration
FUNCTION_NAME="SchoolMonitoringBedrockAnalysis"
ROLE_NAME="SchoolMonitoringLambdaRole"
POLICY_NAME="SchoolMonitoringBedrockPolicy"
REGION="us-east-1"
RUNTIME="python3.11"
S3_BUCKET="school-monitoring-reports"

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"
echo ""

# Prompt for database configuration
echo "Enter your Aurora database configuration:"
read -p "Database Host (Aurora endpoint): " DB_HOST
read -p "Database User: " DB_USER
read -sp "Database Password: " DB_PASSWORD
echo ""
read -p "Database Name [school_monitoring]: " DB_NAME
DB_NAME=${DB_NAME:-school_monitoring}

read -p "VPC Subnet IDs (comma-separated): " SUBNET_IDS
read -p "Security Group ID: " SECURITY_GROUP_ID

echo ""
echo "========================================="
echo "Step 1: Creating IAM Policy"
echo "========================================="

# Create IAM policy
cat > /tmp/bedrock-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": [
        "arn:aws:bedrock:${REGION}::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
        "arn:aws:bedrock:${REGION}::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
        "arn:aws:bedrock:${REGION}::foundation-model/anthropic.claude-v2:1"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::${S3_BUCKET}/*"
    }
  ]
}
EOF

# Create policy (ignore if exists)
aws iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file:///tmp/bedrock-policy.json \
  --region $REGION 2>/dev/null || echo "Policy already exists"

POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
echo "✓ Policy created/verified: $POLICY_ARN"

echo ""
echo "========================================="
echo "Step 2: Creating IAM Role"
echo "========================================="

# Create trust policy
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

# Create role (ignore if exists)
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file:///tmp/trust-policy.json \
  --region $REGION 2>/dev/null || echo "Role already exists"

# Attach policies
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
  --region $REGION 2>/dev/null || true

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole \
  --region $REGION 2>/dev/null || true

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn $POLICY_ARN \
  --region $REGION 2>/dev/null || true

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "✓ Role created/verified: $ROLE_ARN"
echo "  Waiting 10 seconds for IAM propagation..."
sleep 10

echo ""
echo "========================================="
echo "Step 3: Creating S3 Bucket"
echo "========================================="

# Create S3 bucket (ignore if exists)
aws s3 mb s3://$S3_BUCKET --region $REGION 2>/dev/null || echo "Bucket already exists"
echo "✓ S3 bucket ready: s3://$S3_BUCKET"

echo ""
echo "========================================="
echo "Step 4: Packaging Lambda Function"
echo "========================================="

# Create deployment package
rm -rf /tmp/lambda-package
mkdir -p /tmp/lambda-package
cd /tmp/lambda-package

# Create requirements.txt
cat > requirements.txt <<EOF
pymysql==1.1.0
EOF

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt -t . -q

# Copy Lambda function
cp $OLDPWD/bedrock_lambda_function.py lambda_function.py

# Create ZIP
echo "Creating deployment package..."
zip -r ../school-monitoring-bedrock.zip . -q

cd $OLDPWD
echo "✓ Deployment package created: /tmp/school-monitoring-bedrock.zip"

echo ""
echo "========================================="
echo "Step 5: Deploying Lambda Function"
echo "========================================="

# Check if function exists
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION 2>/dev/null; then
    echo "Function exists, updating..."
    
    # Update function code
    aws lambda update-function-code \
      --function-name $FUNCTION_NAME \
      --zip-file fileb:///tmp/school-monitoring-bedrock.zip \
      --region $REGION
    
    # Update configuration
    aws lambda update-function-configuration \
      --function-name $FUNCTION_NAME \
      --environment Variables="{
        DB_HOST=${DB_HOST},
        DB_USER=${DB_USER},
        DB_PASSWORD=${DB_PASSWORD},
        DB_NAME=${DB_NAME},
        S3_BUCKET=${S3_BUCKET},
        AWS_REGION=${REGION}
      }" \
      --region $REGION
    
    echo "✓ Lambda function updated"
else
    echo "Creating new function..."
    
    # Create function
    aws lambda create-function \
      --function-name $FUNCTION_NAME \
      --runtime $RUNTIME \
      --role $ROLE_ARN \
      --handler lambda_function.lambda_handler \
      --zip-file fileb:///tmp/school-monitoring-bedrock.zip \
      --timeout 60 \
      --memory-size 512 \
      --environment Variables="{
        DB_HOST=${DB_HOST},
        DB_USER=${DB_USER},
        DB_PASSWORD=${DB_PASSWORD},
        DB_NAME=${DB_NAME},
        S3_BUCKET=${S3_BUCKET},
        AWS_REGION=${REGION}
      }" \
      --vpc-config SubnetIds=${SUBNET_IDS},SecurityGroupIds=${SECURITY_GROUP_ID} \
      --region $REGION
    
    echo "✓ Lambda function created"
fi

echo ""
echo "========================================="
echo "Step 6: Testing Lambda Function"
echo "========================================="

# Create test event
cat > /tmp/test-event.json <<EOF
{
  "analysis_type": "quick_summary",
  "model": "haiku"
}
EOF

echo "Invoking Lambda function with test event..."
aws lambda invoke \
  --function-name $FUNCTION_NAME \
  --payload file:///tmp/test-event.json \
  --cli-binary-format raw-in-base64-out \
  --region $REGION \
  /tmp/response.json

echo ""
echo "Response:"
cat /tmp/response.json | python3 -m json.tool

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Lambda Function: $FUNCTION_NAME"
echo "Region: $REGION"
echo "S3 Bucket: s3://$S3_BUCKET"
echo ""
echo "Test the function:"
echo "  aws lambda invoke \\"
echo "    --function-name $FUNCTION_NAME \\"
echo "    --payload '{\"analysis_type\":\"comprehensive\",\"model\":\"sonnet\"}' \\"
echo "    --cli-binary-format raw-in-base64-out \\"
echo "    response.json"
echo ""
echo "View logs:"
echo "  aws logs tail /aws/lambda/$FUNCTION_NAME --follow"
echo ""
