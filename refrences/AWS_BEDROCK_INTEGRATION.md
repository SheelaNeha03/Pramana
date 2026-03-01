# AWS Bedrock Integration Guide
## Complete Step-by-Step Setup for School Monitoring KPIs

---

## Overview

This guide shows you how to connect your Aurora MySQL KPI views to AWS Bedrock for AI-powered insights.

**Architecture:**
```
Aurora MySQL (KPI Views) → Lambda Function → AWS Bedrock (Claude) → Insights
```

**Benefits:**
- ✅ Data stays in AWS (compliance-friendly)
- ✅ No external API calls
- ✅ Integrated with AWS services
- ✅ Scalable and secure
- ✅ Cost-effective for high volume

---

## Prerequisites

- [x] AWS Account with appropriate permissions
- [x] Aurora MySQL database with KPI views created
- [x] AWS CLI installed and configured
- [x] Python 3.9+ installed locally

---

## Step 1: Enable AWS Bedrock

### 1.1 Request Model Access

1. Go to AWS Console → **Bedrock**
2. Click **Model access** in left sidebar
3. Click **Manage model access**
4. Select models you want:
   - ✅ **Anthropic Claude 3 Sonnet** (Recommended)
   - ✅ **Anthropic Claude 3 Haiku** (Faster, cheaper)
   - ✅ **Anthropic Claude 2.1** (Alternative)
5. Click **Request model access**
6. Wait for approval (usually instant for Claude)

### 1.2 Verify Access

```bash
# Test Bedrock access
aws bedrock list-foundation-models --region us-east-1
```

You should see Claude models listed.

---

## Step 2: Set Up IAM Permissions

### 2.1 Create IAM Policy for Bedrock

Create file: `bedrock-policy.json`

```json
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
        "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
        "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
      ]
    }
  ]
}
```

### 2.2 Create IAM Role for Lambda

```bash
# Create policy
aws iam create-policy \
  --policy-name SchoolMonitoringBedrockPolicy \
  --policy-document file://bedrock-policy.json

# Create role
aws iam create-role \
  --role-name SchoolMonitoringLambdaRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach policies
aws iam attach-role-policy \
  --role-name SchoolMonitoringLambdaRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
  --role-name SchoolMonitoringLambdaRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole

aws iam attach-role-policy \
  --role-name SchoolMonitoringLambdaRole \
  --policy-arn arn:aws:iam::<YOUR-ACCOUNT-ID>:policy/SchoolMonitoringBedrockPolicy
```

---

## Step 3: Create Lambda Function

### 3.1 Create Lambda Deployment Package

Create file: `lambda_function.py`

```python
import json
import boto3
import pymysql
import os
from datetime import datetime

# Initialize Bedrock client
bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')

# Database configuration from environment variables
DB_HOST = os.environ['DB_HOST']
DB_USER = os.environ['DB_USER']
DB_PASSWORD = os.environ['DB_PASSWORD']
DB_NAME = os.environ['DB_NAME']

def get_db_connection():
    """Create database connection"""
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor
    )

def fetch_district_kpis():
    """Fetch district KPIs from views"""
    conn = get_db_connection()
    
    query = """
    SELECT 
        d.district_name,
        s.state_name,
        ROUND(COALESCE(c.district_performance_index, 0), 2) AS performance_index,
        ROUND(COALESCE(sa.attendance_percentage, 0), 2) AS student_attendance,
        ROUND(COALESCE(ep.pass_percentage, 0), 2) AS pass_rate,
        ROUND(COALESCE(sp.sports_participation_rate, 0), 2) AS sports_participation,
        ROUND(COALESCE(ta.teacher_attendance_percentage, 0), 2) AS teacher_attendance,
        ROUND(COALESCE(i.avg_inspection_score, 0), 2) AS inspection_score
    FROM district d
    JOIN state s ON d.state_id = s.state_id
    LEFT JOIN district_composite_kpi c ON d.district_id = c.district_id
    LEFT JOIN district_student_attendance_kpi sa ON d.district_id = sa.district_id
    LEFT JOIN district_exam_pass_kpi ep ON d.district_id = ep.district_id
    LEFT JOIN district_sports_participation_kpi sp ON d.district_id = sp.district_id
    LEFT JOIN district_teacher_attendance_kpi ta ON d.district_id = ta.district_id
    LEFT JOIN district_inspection_kpi i ON d.district_id = i.district_id
    ORDER BY c.district_performance_index DESC;
    """
    
    try:
        with conn.cursor() as cursor:
            cursor.execute(query)
            results = cursor.fetchall()
        return results
    finally:
        conn.close()

def create_bedrock_prompt(kpi_data, analysis_type='comprehensive'):
    """Create prompt for Bedrock"""
    
    data_json = json.dumps(kpi_data, indent=2)
    
    prompts = {
        'comprehensive': f"""
You are an expert education data analyst for government schools in India.

Analyze this district performance data:

{data_json}

Provide a comprehensive analysis including:

1. EXECUTIVE SUMMARY (2-3 sentences)
2. TOP PERFORMERS (Top 3 districts and success factors)
3. UNDERPERFORMERS (Bottom 3 districts and issues)
4. KEY INSIGHTS (Patterns and correlations)
5. RECOMMENDATIONS (5 specific, actionable items with priority)

Format with clear sections and bullet points.
""",
        'at_risk': f"""
Identify districts at risk based on this data:

{data_json}

For each at-risk district (performance < 60):
1. Risk level (High/Medium/Low)
2. Primary issues
3. Immediate actions (30 days)
4. Medium-term plan (3-6 months)
5. Resources needed

Prioritize by urgency.
""",
        'quick_summary': f"""
Provide a brief summary of district performance:

{data_json}

Include:
- Overall state (1 sentence)
- Top 3 performers
- Bottom 3 performers
- One key recommendation

Keep it concise (under 200 words).
"""
    }
    
    return prompts.get(analysis_type, prompts['comprehensive'])

def invoke_bedrock(prompt, model_id='anthropic.claude-3-sonnet-20240229-v1:0'):
    """Call AWS Bedrock with Claude"""
    
    # Prepare request body for Claude 3
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 2000,
        "messages": [
            {
                "role": "user",
                "content": prompt
            }
        ],
        "temperature": 0.7,
        "top_p": 0.9
    })
    
    # Invoke model
    response = bedrock.invoke_model(
        modelId=model_id,
        body=body
    )
    
    # Parse response
    response_body = json.loads(response['body'].read())
    return response_body['content'][0]['text']

def lambda_handler(event, context):
    """
    Main Lambda handler
    
    Event parameters:
    - analysis_type: 'comprehensive', 'at_risk', or 'quick_summary'
    - model: 'sonnet' (default) or 'haiku'
    """
    
    try:
        # Get parameters
        analysis_type = event.get('analysis_type', 'comprehensive')
        model_choice = event.get('model', 'sonnet')
        
        # Map model choice to model ID
        models = {
            'sonnet': 'anthropic.claude-3-sonnet-20240229-v1:0',
            'haiku': 'anthropic.claude-3-haiku-20240307-v1:0'
        }
        model_id = models.get(model_choice, models['sonnet'])
        
        # Fetch KPIs from database views
        print(f"Fetching KPIs from database...")
        kpi_data = fetch_district_kpis()
        print(f"Fetched {len(kpi_data)} districts")
        
        # Create prompt
        print(f"Creating {analysis_type} prompt...")
        prompt = create_bedrock_prompt(kpi_data, analysis_type)
        
        # Call Bedrock
        print(f"Invoking Bedrock with {model_choice}...")
        analysis = invoke_bedrock(prompt, model_id)
        
        # Return response
        return {
            'statusCode': 200,
            'body': json.dumps({
                'timestamp': datetime.now().isoformat(),
                'analysis_type': analysis_type,
                'model': model_choice,
                'districts_analyzed': len(kpi_data),
                'analysis': analysis
            }, indent=2)
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
```

### 3.2 Create Requirements File

Create file: `requirements.txt`

```
pymysql==1.1.0
boto3==1.34.0
```

### 3.3 Package Lambda Function

```bash
# Create deployment package
mkdir lambda-package
cd lambda-package

# Install dependencies
pip install -r ../requirements.txt -t .

# Copy Lambda function
cp ../lambda_function.py .

# Create ZIP
zip -r ../school-monitoring-bedrock.zip .
cd ..
```

### 3.4 Deploy Lambda Function

```bash
# Create Lambda function
aws lambda create-function \
  --function-name SchoolMonitoringBedrockAnalysis \
  --runtime python3.11 \
  --role arn:aws:iam::<YOUR-ACCOUNT-ID>:role/SchoolMonitoringLambdaRole \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://school-monitoring-bedrock.zip \
  --timeout 60 \
  --memory-size 512 \
  --environment Variables="{
    DB_HOST=your-aurora-endpoint.rds.amazonaws.com,
    DB_USER=your-username,
    DB_PASSWORD=your-password,
    DB_NAME=school_monitoring
  }" \
  --vpc-config SubnetIds=subnet-xxx,subnet-yyy,SecurityGroupIds=sg-xxx
```

**Note:** Replace with your actual Aurora endpoint, credentials, and VPC configuration.

---

## Step 4: Test the Integration

### 4.1 Test Lambda Function

Create test event: `test-event.json`

```json
{
  "analysis_type": "comprehensive",
  "model": "sonnet"
}
```

Test via AWS CLI:

```bash
aws lambda invoke \
  --function-name SchoolMonitoringBedrockAnalysis \
  --payload file://test-event.json \
  --cli-binary-format raw-in-base64-out \
  response.json

# View response
cat response.json | jq .
```

### 4.2 Test Different Analysis Types

**Quick Summary:**
```json
{
  "analysis_type": "quick_summary",
  "model": "haiku"
}
```

**At-Risk Analysis:**
```json
{
  "analysis_type": "at_risk",
  "model": "sonnet"
}
```

---

## Step 5: Create API Gateway (Optional)

### 5.1 Create REST API

```bash
# Create API
aws apigateway create-rest-api \
  --name SchoolMonitoringAPI \
  --description "API for school monitoring analysis"

# Get API ID (from output)
API_ID=<your-api-id>

# Get root resource ID
aws apigateway get-resources --rest-api-id $API_ID

# Create resource
aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id <root-resource-id> \
  --path-part analyze

# Create POST method
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id <resource-id> \
  --http-method POST \
  --authorization-type NONE

# Integrate with Lambda
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id <resource-id> \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:<ACCOUNT-ID>:function:SchoolMonitoringBedrockAnalysis/invocations

# Deploy API
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod
```

### 5.2 Test API

```bash
# Get API endpoint
API_ENDPOINT="https://${API_ID}.execute-api.us-east-1.amazonaws.com/prod/analyze"

# Test with curl
curl -X POST $API_ENDPOINT \
  -H "Content-Type: application/json" \
  -d '{
    "analysis_type": "comprehensive",
    "model": "sonnet"
  }'
```

---

## Step 6: Schedule Automated Reports

### 6.1 Create EventBridge Rule

```bash
# Create rule for daily reports
aws events put-rule \
  --name DailySchoolMonitoringReport \
  --schedule-expression "cron(0 8 * * ? *)" \
  --description "Daily school monitoring analysis at 8 AM UTC"

# Add Lambda as target
aws events put-targets \
  --rule DailySchoolMonitoringReport \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:<ACCOUNT-ID>:function:SchoolMonitoringBedrockAnalysis","Input"='{"analysis_type":"comprehensive","model":"sonnet"}'

# Grant EventBridge permission to invoke Lambda
aws lambda add-permission \
  --function-name SchoolMonitoringBedrockAnalysis \
  --statement-id DailyReportPermission \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:us-east-1:<ACCOUNT-ID>:rule/DailySchoolMonitoringReport
```

---

## Step 7: Store Results in S3

### 7.1 Update Lambda to Save to S3

Add to `lambda_function.py`:

```python
import boto3

s3 = boto3.client('s3')
BUCKET_NAME = 'school-monitoring-reports'

def save_to_s3(analysis, analysis_type):
    """Save analysis to S3"""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    key = f"reports/{analysis_type}/{timestamp}.json"
    
    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=key,
        Body=json.dumps({
            'timestamp': datetime.now().isoformat(),
            'analysis_type': analysis_type,
            'analysis': analysis
        }, indent=2),
        ContentType='application/json'
    )
    
    return f"s3://{BUCKET_NAME}/{key}"

# In lambda_handler, add:
s3_path = save_to_s3(analysis, analysis_type)
```

### 7.2 Create S3 Bucket

```bash
aws s3 mb s3://school-monitoring-reports
```

---

## Step 8: Monitor and Optimize

### 8.1 Set Up CloudWatch Alarms

```bash
# Alarm for Lambda errors
aws cloudwatch put-metric-alarm \
  --alarm-name SchoolMonitoringLambdaErrors \
  --alarm-description "Alert on Lambda errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=SchoolMonitoringBedrockAnalysis
```

### 8.2 View Logs

```bash
# View Lambda logs
aws logs tail /aws/lambda/SchoolMonitoringBedrockAnalysis --follow
```

---

## Cost Optimization

### Model Pricing (as of 2024)

**Claude 3 Sonnet:**
- Input: $3 per 1M tokens
- Output: $15 per 1M tokens

**Claude 3 Haiku:**
- Input: $0.25 per 1M tokens
- Output: $1.25 per 1M tokens

### Recommendations:

1. **Use Haiku for frequent queries** (quick summaries, alerts)
2. **Use Sonnet for detailed analysis** (monthly reports, strategic planning)
3. **Cache results** for repeated queries
4. **Batch requests** when possible

### Estimated Costs:

**Daily comprehensive report:**
- Input: ~2,000 tokens
- Output: ~1,500 tokens
- Cost with Sonnet: ~$0.03/day = ~$1/month
- Cost with Haiku: ~$0.002/day = ~$0.06/month

**Very affordable!**

---

## Troubleshooting

### Issue: Lambda timeout
**Solution:** Increase timeout to 60-120 seconds

### Issue: Database connection fails
**Solution:** Ensure Lambda is in same VPC as Aurora, check security groups

### Issue: Bedrock access denied
**Solution:** Verify model access is enabled, check IAM permissions

### Issue: Large response truncated
**Solution:** Increase max_tokens in Bedrock request

---

## Next Steps

1. ✅ Test basic integration
2. ✅ Set up automated daily reports
3. ✅ Create dashboard to display insights
4. ✅ Add email notifications (SNS)
5. ✅ Implement caching for common queries
6. ✅ Add more analysis types (predictive, comparative)

---

## Complete Example Usage

```python
# Local testing script
import boto3
import json

lambda_client = boto3.client('lambda', region_name='us-east-1')

# Invoke Lambda
response = lambda_client.invoke(
    FunctionName='SchoolMonitoringBedrockAnalysis',
    InvocationType='RequestResponse',
    Payload=json.dumps({
        'analysis_type': 'comprehensive',
        'model': 'sonnet'
    })
)

# Parse response
result = json.loads(response['Payload'].read())
analysis = json.loads(result['body'])

print(analysis['analysis'])
```

---

## Summary

You now have:
- ✅ Aurora KPI views connected to Bedrock
- ✅ Lambda function for analysis
- ✅ API endpoint (optional)
- ✅ Automated daily reports
- ✅ Results stored in S3
- ✅ Monitoring and alerts

**Your KPIs are now AI-powered!** 🚀
