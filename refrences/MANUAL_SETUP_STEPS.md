# Manual Setup Steps for AWS Bedrock Integration

Follow these steps one by one to set up the integration manually.

---

## Prerequisites

- AWS CLI installed and configured
- Your AWS Account ID (get it with: `aws sts get-caller-identity`)
- Aurora database endpoint and credentials
- VPC Subnet IDs and Security Group ID where Aurora is located

---

## Step 1: Enable Bedrock Models (AWS Console)

1. Go to AWS Console → Search for "Bedrock"
2. Click on **Bedrock** service
3. In left sidebar, click **Model access**
4. Click **Manage model access** button
5. Check these models:
   - ✅ Anthropic Claude 3 Sonnet
   - ✅ Anthropic Claude 3 Haiku
6. Click **Request model access**
7. Wait for approval (usually instant)

**Verify:**
```bash
aws bedrock list-foundation-models --region us-east-1 | grep claude
```

---

## Step 2: Get Your AWS Account ID

```bash
aws sts get-caller-identity --query Account --output text
```

Save this number - you'll need it multiple times. Let's call it `YOUR-ACCOUNT-ID`.

---

## Step 3: Create IAM Policy

The file `bedrock-policy.json` is already created in your directory.

**Create the policy:**
```bash
aws iam create-policy \
  --policy-name SchoolMonitoringBedrockPolicy \
  --policy-document file://bedrock-policy.json \
  --region us-east-1
```

**Expected output:**
```json
{
    "Policy": {
        "PolicyName": "SchoolMonitoringBedrockPolicy",
        "PolicyId": "ANPA...",
        "Arn": "arn:aws:iam::YOUR-ACCOUNT-ID:policy/SchoolMonitoringBedrockPolicy",
        ...
    }
}
```

**Save the Policy ARN** - you'll need it in Step 4.

---

## Step 4: Create IAM Role

The file `trust-policy.json` is already created in your directory.

**Create the role:**
```bash
aws iam create-role \
  --role-name SchoolMonitoringLambdaRole \
  --assume-role-policy-document file://trust-policy.json \
  --region us-east-1
```

**Expected output:**
```json
{
    "Role": {
        "RoleName": "SchoolMonitoringLambdaRole",
        "Arn": "arn:aws:iam::YOUR-ACCOUNT-ID:role/SchoolMonitoringLambdaRole",
        ...
    }
}
```

---

## Step 5: Attach Policies to Role

**Attach AWS managed policies:**
```bash
# Basic Lambda execution
aws iam attach-role-policy \
  --role-name SchoolMonitoringLambdaRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# VPC access (for Aurora connection)
aws iam attach-role-policy \
  --role-name SchoolMonitoringLambdaRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
```

**Attach your custom Bedrock policy:**
```bash
# Replace YOUR-ACCOUNT-ID with your actual account ID
aws iam attach-role-policy \
  --role-name SchoolMonitoringLambdaRole \
  --policy-arn arn:aws:iam::YOUR-ACCOUNT-ID:policy/SchoolMonitoringBedrockPolicy
```

**Wait 10 seconds for IAM propagation:**
```bash
sleep 10
```

---

## Step 6: Create S3 Bucket for Reports

```bash
aws s3 mb s3://school-monitoring-reports --region us-east-1
```

**If bucket name is taken, use a unique name:**
```bash
aws s3 mb s3://school-monitoring-reports-YOUR-ACCOUNT-ID --region us-east-1
```

**Note:** If you use a different bucket name, update it in the Lambda environment variables later.

---

## Step 7: Package Lambda Function

**Install dependencies:**
```bash
# Create a temporary directory
mkdir lambda-package
cd lambda-package

# Create requirements file
echo "pymysql==1.1.0" > requirements.txt

# Install dependencies
pip install -r requirements.txt -t .

# Copy Lambda function
cp ../bedrock_lambda_function.py lambda_function.py

# Create ZIP file
zip -r ../school-monitoring-bedrock.zip .

# Go back to main directory
cd ..
```

**Verify the ZIP was created:**
```bash
ls -lh school-monitoring-bedrock.zip
```

You should see a file around 1-2 MB.

---

## Step 8: Get Your VPC Configuration

You need:
1. **Subnet IDs** (where Aurora is located)
2. **Security Group ID** (that allows Lambda to access Aurora)

**Find your Aurora VPC configuration:**
```bash
# Get Aurora cluster info
aws rds describe-db-clusters --query 'DBClusters[*].[DBClusterIdentifier,VpcSecurityGroups,DBSubnetGroup]' --output table
```

**Or check in AWS Console:**
1. Go to RDS → Databases
2. Click on your Aurora cluster
3. Under "Connectivity & security":
   - Note the **Subnets** (you need at least 2)
   - Note the **Security group ID**

**Format for Lambda:**
- Subnet IDs: `subnet-abc123,subnet-def456` (comma-separated, no spaces)
- Security Group: `sg-xyz789`

---

## Step 9: Create Lambda Function

**Replace these values:**
- `YOUR-ACCOUNT-ID` - Your AWS account ID
- `YOUR-AURORA-ENDPOINT` - Your Aurora endpoint (e.g., `cluster-name.cluster-xxx.us-east-1.rds.amazonaws.com`)
- `YOUR-DB-USER` - Database username
- `YOUR-DB-PASSWORD` - Database password
- `subnet-xxx,subnet-yyy` - Your subnet IDs (comma-separated)
- `sg-xxx` - Your security group ID

```bash
aws lambda create-function \
  --function-name SchoolMonitoringBedrockAnalysis \
  --runtime python3.11 \
  --role arn:aws:iam::YOUR-ACCOUNT-ID:role/SchoolMonitoringLambdaRole \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://school-monitoring-bedrock.zip \
  --timeout 60 \
  --memory-size 512 \
  --environment Variables="{DB_HOST=YOUR-AURORA-ENDPOINT,DB_USER=YOUR-DB-USER,DB_PASSWORD=YOUR-DB-PASSWORD,DB_NAME=school_monitoring,S3_BUCKET=school-monitoring-reports,AWS_REGION=us-east-1}" \
  --vpc-config SubnetIds=subnet-xxx,subnet-yyy,SecurityGroupIds=sg-xxx \
  --region us-east-1
```

**Expected output:**
```json
{
    "FunctionName": "SchoolMonitoringBedrockAnalysis",
    "FunctionArn": "arn:aws:lambda:us-east-1:YOUR-ACCOUNT-ID:function:SchoolMonitoringBedrockAnalysis",
    ...
}
```

---

## Step 10: Test Lambda Function

**Create test event file:**
```bash
cat > test-event.json <<EOF
{
  "analysis_type": "quick_summary",
  "model": "haiku"
}
EOF
```

**Invoke Lambda:**
```bash
aws lambda invoke \
  --function-name SchoolMonitoringBedrockAnalysis \
  --payload file://test-event.json \
  --cli-binary-format raw-in-base64-out \
  response.json
```

**View response:**
```bash
cat response.json | python -m json.tool
```

**Or if you have jq installed:**
```bash
cat response.json | jq .
```

---

## Step 11: Check Lambda Logs

```bash
aws logs tail /aws/lambda/SchoolMonitoringBedrockAnalysis --follow
```

Press `Ctrl+C` to stop following logs.

---

## Troubleshooting

### Error: "AccessDeniedException" from Bedrock
**Solution:** Go back to Step 1 and enable model access in Bedrock console

### Error: "Unable to import module 'lambda_function'"
**Solution:** Recreate the ZIP file, ensure `lambda_function.py` is at the root level

### Error: Database connection timeout
**Solution:** 
1. Check VPC configuration (subnets and security group)
2. Ensure security group allows inbound traffic from Lambda
3. Verify Aurora endpoint is correct

### Error: "Role not found"
**Solution:** Wait 30 seconds for IAM propagation, then try again

---

## Verify Everything Works

**Test different analysis types:**

```bash
# Quick summary (fast, cheap)
aws lambda invoke \
  --function-name SchoolMonitoringBedrockAnalysis \
  --payload '{"analysis_type":"quick_summary","model":"haiku"}' \
  --cli-binary-format raw-in-base64-out \
  response.json && cat response.json | jq .body | jq -r . | jq .analysis

# Comprehensive analysis
aws lambda invoke \
  --function-name SchoolMonitoringBedrockAnalysis \
  --payload '{"analysis_type":"comprehensive","model":"sonnet"}' \
  --cli-binary-format raw-in-base64-out \
  response.json && cat response.json | jq .body | jq -r . | jq .analysis

# At-risk districts
aws lambda invoke \
  --function-name SchoolMonitoringBedrockAnalysis \
  --payload '{"analysis_type":"at_risk","model":"sonnet"}' \
  --cli-binary-format raw-in-base64-out \
  response.json && cat response.json | jq .body | jq -r . | jq .analysis
```

---

## Next Steps

Once everything works:

1. **Set up automated reports** (see BEDROCK_QUICK_START.md)
2. **Create API Gateway** (optional, for HTTP access)
3. **Add email notifications** (SNS integration)
4. **Build dashboard** (to display insights)

---

## Quick Reference

**View logs:**
```bash
aws logs tail /aws/lambda/SchoolMonitoringBedrockAnalysis --follow
```

**Update Lambda code:**
```bash
# After making changes to bedrock_lambda_function.py
cd lambda-package
cp ../bedrock_lambda_function.py lambda_function.py
zip -r ../school-monitoring-bedrock.zip .
cd ..

aws lambda update-function-code \
  --function-name SchoolMonitoringBedrockAnalysis \
  --zip-file fileb://school-monitoring-bedrock.zip
```

**Update environment variables:**
```bash
aws lambda update-function-configuration \
  --function-name SchoolMonitoringBedrockAnalysis \
  --environment Variables="{DB_HOST=new-endpoint,DB_USER=user,DB_PASSWORD=pass,DB_NAME=school_monitoring,S3_BUCKET=school-monitoring-reports,AWS_REGION=us-east-1}"
```

**Delete everything (cleanup):**
```bash
# Delete Lambda function
aws lambda delete-function --function-name SchoolMonitoringBedrockAnalysis

# Detach and delete role
aws iam detach-role-policy --role-name SchoolMonitoringLambdaRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam detach-role-policy --role-name SchoolMonitoringLambdaRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
aws iam detach-role-policy --role-name SchoolMonitoringLambdaRole --policy-arn arn:aws:iam::YOUR-ACCOUNT-ID:policy/SchoolMonitoringBedrockPolicy
aws iam delete-role --role-name SchoolMonitoringLambdaRole

# Delete policy
aws iam delete-policy --policy-arn arn:aws:iam::YOUR-ACCOUNT-ID:policy/SchoolMonitoringBedrockPolicy

# Delete S3 bucket (careful!)
aws s3 rb s3://school-monitoring-reports --force
```

---

## Summary

You've successfully:
- ✅ Enabled Bedrock models
- ✅ Created IAM policy and role
- ✅ Created S3 bucket
- ✅ Deployed Lambda function
- ✅ Tested the integration

**Your KPIs are now connected to AWS Bedrock!** 🎉
